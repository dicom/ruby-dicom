#    Copyright 2009-2010 Christoffer Lervag

module DICOM

  # This class handles the construction and interpretation of network packages as well as network communication.
  #
  class Link

    attr_accessor :file_handler, :max_package_size, :presentation_contexts, :verbose
    attr_reader :errors, :notices, :session

    # Initializes a Link instance, which is used by both DClient and DServer to handle network communication.
    #
    def initialize(options={})
      require 'socket'
      # Optional parameters (and default values):
      @file_handler = options[:file_handler] || FileHandler
      @ae =  options[:ae]  || "RUBY_DICOM"
      @host_ae =  options[:host_ae]  || "DEFAULT"
      @max_package_size = options[:max_package_size] || 32768 # 16384
      @max_receive_size = @max_package_size
      @timeout = options[:timeout] || 10 # seconds
      @min_length = 10 # minimum number of bytes to expect in an incoming transmission
      @verbose = options[:verbose]
      @verbose = true if @verbose == nil # Default verbosity is 'on'.
      # Other instance variables:
      @errors = Array.new # errors and warnings are put in this array
      @notices = Array.new # information on successful transmissions are put in this array
      # Variables used for monitoring state of transmission:
      @session = nil # TCP connection
      @association = nil # DICOM Association status
      @request_approved = nil # Status of our DICOM request
      @release = nil # Status of received, valid release response
      @command_request = Hash.new
      @presentation_contexts = Hash.new # Keeps track of the relationship between pc id and it's transfer syntax
      set_default_values
      set_user_information_array
      @outgoing = Stream.new(string=nil, endian=true)
    end

    # Waits for SCU to issue a release request, which is then answered by a release response.
    #
    def await_release
      segments = receive_single_transmission
      info = segments.first
      if info[:pdu] != PDU_RELEASE_REQUEST
        # For some reason we didnt get our expected release request. Determine why:
        if info[:valid]
          add_error("Unexpected message type received (PDU: #{info[:pdu]}). Expected a release request. Closing the connection.")
          handle_abort(false)
        else
          add_error("Timed out while waiting for a release request. Closing the connection.")
        end
        stop_session
      else
        # Properly release the association:
        handle_release
      end
    end

    # Builds the abort message which is transmitted when the server wishes to (abruptly) abort the connection.
    # For the moment: NO REASONS WILL BE PROVIDED (and source of problems will always be set as client side).
    #
    def build_association_abort
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Reserved (2 bytes)
      @outgoing.encode_last("00"*2, "HEX")
      # Source (1 byte)
      source = "00" # (client side error)
      @outgoing.encode_last(source, "HEX")
      # Reason/Diag. (1 byte)
      reason = "00" # (Reason not specified)
      @outgoing.encode_last(reason, "HEX")
      append_header(PDU_ABORT)
    end

    # Builds the binary string that will be sent as TCP data in the Association accept response.
    #
    def build_association_accept(info, ac_uid, ui)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # No abstract syntax in association response. To make this work with the method that
      # encodes the presentation context, we pass on a one-element array containing nil).
      abstract_syntaxes = Array.new(1, nil)
      # Note: The order of which these components are built is not arbitrary.
      append_application_context(ac_uid)
      # Reset the presentation context instance variable:
      @presentation_contexts = Hash.new
      # Build the presentation context strings, one by one:
      info[:pc].each do |pc|
        context_id = pc[:presentation_context_id]
        result = pc[:result]
        transfer_syntax = pc[:selected_transfer_syntax]
        @presentation_contexts[context_id] = transfer_syntax
        append_presentation_contexts(abstract_syntaxes, ITEM_PRESENTATION_CONTEXT_RESPONSE, transfer_syntax, context_id, result)
      end
      append_user_information(ui)
      # Header must be built last, because we need to know the length of the other components.
      append_association_header(PDU_ASSOCIATION_ACCEPT, info[:called_ae])
    end

    # Builds the binary string that will be sent as TCP data in the association rejection.
    # NB: For the moment, this method will only customize the "reason" value.
    # For a list of error codes, see the official dicom PS3.8 document, page 41.
    #
    def build_association_reject(info)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Reserved (1 byte)
      @outgoing.encode_last("00", "HEX")
      # Result (1 byte)
      @outgoing.encode_last("01", "HEX") # 1 for permament, 2 for transient
      # Source (1 byte)
      # (1: Service user, 2: Service provider (ACSE related function), 3: Service provider (Presentation related function)
      @outgoing.encode_last("01", "HEX")
      # Reason (1 byte)
      reason = info[:reason]
      @outgoing.encode_last(reason, "HEX")
      append_header(PDU_ASSOCIATION_REJECT)
    end

    # Builds the binary string that will be sent as TCP data in the Association request.
    #
    def build_association_request(ac_uid, as, ts, ui)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Note: The order of which these components are built is not arbitrary.
      # (The first three are built 'in order of appearance', the header is built last, but is put first in the message)
      append_application_context(ac_uid)
      append_presentation_contexts(as, ITEM_PRESENTATION_CONTEXT_REQUEST, ts)
      append_user_information(ui)
      # Header must be built last, because we need to know the length of the other components.
      append_association_header(PDU_ASSOCIATION_REQUEST, @host_ae)
    end

    # Builds the binary string that will be sent as TCP data in the query command fragment.
    #
    def build_command_fragment(pdu, context, flags, command_elements)
      # Little endian encoding:
      @outgoing.set_endian(@data_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Build the last part first, the Command items:
      command_elements.each do |element|
        # Tag (4 bytes)
        @outgoing.add_last(@outgoing.encode_tag(element[0]))
        # Encode the value first, so we know its length:
        value = @outgoing.encode_value(element[2], element[1])
        # Length (2 bytes)
        @outgoing.encode_last(value.length, "US")
        # Reserved (2 bytes)
        @outgoing.encode_last("0000", "HEX")
        # Value (variable length)
        @outgoing.add_last(value)
      end
      # The rest of the command fragment will be buildt in reverse, all the time
      # putting the elements first in the outgoing binary string.
      # Group length item:
      # Value (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # Reserved (2 bytes)
      @outgoing.encode_first("0000", "HEX")
      # Length (2 bytes)
      @outgoing.encode_first(4, "US")
      # Tag (4 bytes)
      @outgoing.add_first(@outgoing.encode_tag("0000,0000"))
      # Big endian encoding from now on:
      @outgoing.set_endian(@net_endian)
      # Flags (1 byte)
      @outgoing.encode_first(flags, "HEX") # Command, last fragment (identifier)
      # Presentation context ID (1 byte)
      @outgoing.encode_first(context, "BY") # References the presentation context in the association request/response
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(pdu)
    end

    # Builds the binary string that will be sent as TCP data in the query data fragment.
    # The style of encoding will depend on whether we have an implicit or explicit transfer syntax.
    #
    def build_data_fragment(data_elements, presentation_context_id)
      # Set the transfer syntax to be used for encoding the data fragment:
      set_transfer_syntax(@presentation_contexts[presentation_context_id])
      # Endianness of data fragment:
      @outgoing.set_endian(@data_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Build the last part first, the Data items:
      data_elements.each do |element|
        # Encode all tags (even tags which are empty):
        # Tag (4 bytes)
        @outgoing.add_last(@outgoing.encode_tag(element[0]))
        # Encode the value in advance of putting it into the message, so we know its length:
        vr = LIBRARY.get_name_vr(element[0])[1]
        value = @outgoing.encode_value(element[1], vr)
        if @explicit
          # Type (VR) (2 bytes)
          @outgoing.encode_last(vr, "STR")
          # Length (2 bytes)
          @outgoing.encode_last(value.length, "US")
        else
          # Implicit:
          # Length (4 bytes)
          @outgoing.encode_last(value.length, "UL")
        end
        # Value (variable length)
        @outgoing.add_last(value)
      end
      # The rest of the data fragment will be built in reverse, all the time
      # putting the elements first in the outgoing binary string.
      # Big endian encoding from now on:
      @outgoing.set_endian(@net_endian)
      # Flags (1 byte)
      @outgoing.encode_first("02", "HEX") # Data, last fragment (identifier)
      # Presentation context ID (1 byte)
      @outgoing.encode_first(presentation_context_id, "BY")
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(PDU_DATA)
    end

    # Builds the binary string that will be sent as TCP data in the association release request:
    #
    def build_release_request
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Reserved (4 bytes)
      @outgoing.encode_last("00"*4, "HEX")
      append_header(PDU_RELEASE_REQUEST)
    end

    # Builds the binary string that will be sent as TCP data in the association release response.
    #
    def build_release_response
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Reserved (4 bytes)
      @outgoing.encode_last("00000000", "HEX")
      append_header(PDU_RELEASE_RESPONSE)
    end

    # Builds the binary string that makes up the storage data fragment.
    #
    def build_storage_fragment(pdu, context, flags, body)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Build in reverse, putting elements in front of the binary string:
      # Insert the data (body):
      @outgoing.add_last(body)
      # Flags (1 byte)
      @outgoing.encode_first(flags, "HEX")
      # Context ID (1 byte)
      @outgoing.encode_first(context, "BY")
      # PDV Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(pdu)
    end

    # Delegates an incoming message to its correct interpreter method, based on pdu type.
    #
    def forward_to_interpret(message, pdu, file=nil)
      case pdu
        when PDU_ASSOCIATION_REQUEST
          info = interpret_association_request(message)
        when PDU_ASSOCIATION_ACCEPT
          info = interpret_association_accept(message)
        when PDU_ASSOCIATION_REJECT
          info = interpret_association_reject(message)
        when PDU_DATA
          info = interpret_command_and_data(message, file)
        when PDU_RELEASE_REQUEST
          info = interpret_release_request(message)
        when PDU_RELEASE_RESPONSE
          info = interpret_release_response(message)
        when PDU_ABORT
          info = interpret_abort(message)
        else
          info = {:valid => false}
          add_error("An unknown PDU type was received in the incoming transmission. Can not decode this message. (PDU: #{pdu})")
      end
      return info
    end

    # Handles the abortion of a session, when a non-valid or unexpected message has been received.
    #
    def handle_abort(default_message=true)
      add_notice("An unregonizable (non-DICOM) message was received.") if default_message
      build_association_abort
      transmit
    end

    # Handles the outgoing association accept.
    #
    def handle_association_accept(info)
      # Update the variable for calling ae (information gathered in the association request):
      @ae = info[:calling_ae]
      application_context = info[:application_context]
      # Build message string and send it:
      set_user_information_array(info)
      build_association_accept(info, application_context, @user_information)
      transmit
    end

    # Processes the data that was sent to us.
    # This is expected to be one or more combinations of: A C-STORE-RQ (command fragment) followed by a bunch of data fragments.
    # It may also be a C-ECHO-RQ command fragment, which is used to test connections.
    # FIXME: The code which handles incoming data isnt quite satisfactory. It would probably be wise to rewrite it at some stage
    # to clean up the code somewhat. Probably a better handling of command requests (and their corresponding data fragments) would be a good idea.
    #
    def handle_incoming_data(path)
      # Wait for incoming data:
      segments = receive_multiple_transmissions(file=true)
      # Reset command results arrays:
      @command_results = Array.new
      @data_results = Array.new
      file_transfer_syntaxes = Array.new
      files = Array.new
      single_file_data = Array.new
      # Proceed to extract data from the captured segments:
      segments.each do |info|
        if info[:valid]
          # Determine if it is command or data:
          if info[:presentation_context_flag] == DATA_MORE_FRAGMENTS
            @data_results << info[:results]
            single_file_data  << info[:bin]
          elsif info[:presentation_context_flag] == DATA_LAST_FRAGMENT
            @data_results << info[:results]
            single_file_data  << info[:bin]
            # Join the recorded data binary strings together to make a DICOM file binary string and put it in our files Array:
            files << single_file_data.join
            single_file_data = Array.new
          elsif info[:presentation_context_flag] == COMMAND_LAST_FRAGMENT
            @command_results << info[:results]
            @presentation_context_id = info[:presentation_context_id] # Does this actually do anything useful?
            file_transfer_syntaxes << @presentation_contexts[info[:presentation_context_id]]
          end
        end
      end
      # Process the received files using the customizable FileHandler class:
      success, messages = @file_handler.receive_files(path, files, file_transfer_syntaxes)
      return success, messages
    end

    # Handles the rejection of an association, when the formalities of the association is not correct.
    #
    def handle_rejection
      add_notice("An incoming association request was rejected. Error code: #{association_error}")
      # Insert the error code in the info hash:
      info[:reason] = association_error
      # Send an association rejection:
      build_association_reject(info)
      transmit
    end

    # Handles the release of an association from the provider side (expects a release request, which it responds to).
    #
    def handle_release
      stop_receiving
      add_notice("Received a release request. Releasing association.")
      build_release_response
      transmit
      stop_session
    end

    # Handles the response (C-STORE-RSP) when a DICOM object, following an initial C-STORE-RQ, has been (successfully) received.
    #
    def handle_response
      # Need to construct the command elements array:
      command_elements = Array.new
      # SOP Class UID:
      command_elements << ["0000,0002", "UI", @command_request["0000,0002"]]
      # Command Field:
      command_elements << ["0000,0100", "US", command_field_response(@command_request["0000,0100"])]
      # Message ID Being Responded To:
      command_elements << ["0000,0120", "US", @command_request["0000,0110"]]
      # Data Set Type:
      command_elements << ["0000,0800", "US", NO_DATA_SET_PRESENT]
      # Status:
      command_elements << ["0000,0900", "US", SUCCESS]
      # Affected SOP Instance UID:
      command_elements << ["0000,1000", "UI", @command_request["0000,1000"]] if @command_request["0000,1000"]
      build_command_fragment(PDU_DATA, @presentation_context_id, COMMAND_LAST_FRAGMENT, command_elements)
      transmit
    end

    # Decodes an incoming transmission., decides its type, and forwards its content to the various methods that process these.
    #
    def interpret(message, file=nil)
      if @first_part
        message = @first_part + message
        @first_part = nil
      end
      segments = Array.new
      # If the message is at least 8 bytes we can start decoding it:
      if message.length > 8
        # Create a new Stream instance to handle this response.
        msg = Stream.new(message, @net_endian)
        # PDU type ( 1 byte)
        pdu = msg.decode(1, "HEX")
        # Reserved (1 byte)
        msg.skip(1)
        # Length of remaining data (4 bytes)
        specified_length = msg.decode(4, "UL")
        # Analyze the remaining length of the message versurs the specified_length value:
        if msg.rest_length > specified_length
          # If the remaining length of the string itself is bigger than this specified_length value,
          # then it seems that we have another message appended in our incoming transmission.
          fragment = msg.extract(specified_length)
          info = forward_to_interpret(fragment, pdu, file)
          info[:pdu] = pdu
          segments << info
          # It is possible that a fragment contains both a command and a data fragment. If so, we need to make sure we collect all the information:
          if info[:rest_string]
            additional_info = forward_to_interpret(info[:rest_string], pdu, file)
            segments << additional_info
          end
          # The information gathered from the interpretation is appended to a segments array,
          # and in the case of a recursive call some special logic is needed to build this array in the expected fashion.
          remaining_segments = interpret(msg.rest_string, file)
          remaining_segments.each do |remaining|
            segments << remaining
          end
        elsif msg.rest_length == specified_length
          # Proceed to analyze the rest of the message:
          fragment = msg.extract(specified_length)
          info = forward_to_interpret(fragment, pdu, file)
          info[:pdu] = pdu
          segments << info
          # It is possible that a fragment contains both a command and a data fragment. If so, we need to make sure we collect all the information:
          if info[:rest_string]
            additional_info = forward_to_interpret(info[:rest_string], pdu, file)
            segments << additional_info
          end
        else
          # Length of the message is less than what is specified in the message. Need to listen for more. This is hopefully handled properly now.
          #add_error("Error. The length of the received message (#{msg.rest_length}) is smaller than what it claims (#{specified_length}). Aborting.")
          @first_part = msg.string
        end
      else
        # Assume that this is only the start of the message, and add it to the next incoming string:
        @first_part = message
      end
      return segments
    end

    # Decodes the binary string received when the provider wishes to abort the connection.
    #
    def interpret_abort(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian)
      # Reserved (2 bytes)
      reserved_bytes = msg.skip(2)
      # Source (1 byte)
      info[:source] = msg.decode(1, "HEX")
      # Reason/Diag. (1 byte)
      info[:reason] = msg.decode(1, "HEX")
      # Analyse the results:
      process_source(info[:source])
      process_reason(info[:reason])
      stop_receiving
      @abort = true
      info[:valid] = true
      return info
    end

    # Decodes the binary string received in the association response, and interprets its content.
    #
    def interpret_association_accept(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian)
      # Protocol version (2 bytes)
      info[:protocol_version] = msg.decode(2, "HEX")
      # Reserved (2 bytes)
      msg.skip(2)
      # Called AE (shall be identical to the one sent in the request, but not tested against) (16 bytes)
      info[:called_ae] = msg.decode(16, "STR")
      # Calling AE (shall be identical to the one sent in the request, but not tested against) (16 bytes)
      info[:calling_ae] = msg.decode(16, "STR")
      # Reserved (32 bytes)
      msg.skip(32)
      # APPLICATION CONTEXT:
      # Item type (1 byte)
      info[:application_item_type] = msg.decode(1, "HEX")
      # Reserved (1 byte)
      msg.skip(1)
      # Application item length (2 bytes)
      info[:application_item_length] = msg.decode(2, "US")
      # Application context (variable length)
      info[:application_context] = msg.decode(info[:application_item_length], "STR")
      # PRESENTATION CONTEXT:
      # As multiple presentation contexts may occur, we need a loop to catch them all:
      # Each presentation context hash will be put in an array, which will be put in the info hash.
      presentation_contexts = Array.new
      pc_loop = true
      while pc_loop do
        # Item type (1 byte)
        item_type = msg.decode(1, "HEX")
        if item_type == ITEM_PRESENTATION_CONTEXT_RESPONSE
          pc = Hash.new
          pc[:presentation_item_type] = item_type
          # Reserved (1 byte)
          msg.skip(1)
          # Presentation item length (2 bytes)
          pc[:presentation_item_length] = msg.decode(2, "US")
          # Presentation context ID (1 byte)
          pc[:presentation_context_id] = msg.decode(1, "BY")
          # Reserved (1 byte)
          msg.skip(1)
          # Result (& Reason) (1 byte)
          pc[:result] = msg.decode(1, "BY")
          process_result(pc[:result])
          # Reserved (1 byte)
          msg.skip(1)
          # Transfer syntax sub-item:
          # Item type (1 byte)
          pc[:transfer_syntax_item_type] = msg.decode(1, "HEX")
          # Reserved (1 byte)
          msg.skip(1)
          # Transfer syntax item length (2 bytes)
          pc[:transfer_syntax_item_length] = msg.decode(2, "US")
          # Transfer syntax name (variable length)
          pc[:transfer_syntax] = msg.decode(pc[:transfer_syntax_item_length], "STR")
          presentation_contexts << pc
        else
          # Break the presentation context loop, as we have probably reached the next stage, which is user info. Rewind:
          msg.skip(-1)
          pc_loop = false
        end
      end
      info[:pc] = presentation_contexts
      # USER INFORMATION:
      # Item type (1 byte)
      info[:user_info_item_type] = msg.decode(1, "HEX")
      # Reserved (1 byte)
      msg.skip(1)
      # User information item length (2 bytes)
      info[:user_info_item_length] = msg.decode(2, "US")
      while msg.index < msg.length do
        # Item type (1 byte)
        item_type = msg.decode(1, "HEX")
        # Reserved (1 byte)
        msg.skip(1)
        # Item length (2 bytes)
        item_length = msg.decode(2, "US")
        case item_type
          when ITEM_MAX_LENGTH
            info[:max_pdu_length] = msg.decode(item_length, "UL")
            @max_receive_size = info[:max_pdu_length]
          when ITEM_IMPLEMENTATION_UID
            info[:implementation_class_uid] = msg.decode(item_length, "STR")
          when ITEM_MAX_OPERATIONS_INVOKED
            # Asynchronous operations window negotiation (PS 3.7: D.3.3.3) (2*2 bytes)
            info[:maxnum_operations_invoked] = msg.decode(2, "US")
            info[:maxnum_operations_performed] = msg.decode(2, "US")
          when ITEM_ROLE_NEGOTIATION
            # SCP/SCU Role Selection Negotiation (PS 3.7 D.3.3.4)
            # Note: An association response may contain several instances of this item type (each with a different abstract syntax).
            uid_length = msg.decode(2, "US")
            role = Hash.new
            # SOP Class UID (Abstract syntax):
            role[:sop_uid] = msg.decode(uid_length, "STR")
            # SCU Role (1 byte):
            role[:scu] = msg.decode(1, "BY")
            # SCP Role (1 byte):
            role[:scp] = msg.decode(1, "BY")
            if info[:role_negotiation]
              info[:role_negotiation] << role
            else
              info[:role_negotiation] = [role]
            end
          when ITEM_IMPLEMENTATION_VERSION
            info[:implementation_version] = msg.decode(item_length, "STR")
          else
            # Value (variable length)
            value = msg.decode(item_length, "STR")
            add_error("Unknown user info item type received. Please update source code or contact author. (item type: " + item_type + ")")
        end
      end
      stop_receiving
      info[:valid] = true
      return info
    end

    # Decodes the association reject message and extracts the error reasons given.
    #
    def interpret_association_reject(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian)
      # Reserved (1 byte)
      msg.skip(1)
      # Result (1 byte)
      info[:result] = msg.decode(1, "BY") # 1 for permanent and 2 for transient rejection
      # Source (1 byte)
      info[:source] = msg.decode(1, "BY")
      # Reason (1 byte)
      info[:reason] = msg.decode(1, "BY")
      add_error("Warning: ASSOCIATE Request was rejected by the host. Error codes: Result: #{info[:result]}, Source: #{info[:source]}, Reason: #{info[:reason]} (See DICOM PS3.8: Table 9-21 for details.)")
      stop_receiving
      info[:valid] = true
      return info
    end

    # Decodes the binary string received in the association request, and interprets its content.
    #
    def interpret_association_request(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian)
      # Protocol version (2 bytes)
      info[:protocol_version] = msg.decode(2, "HEX")
      # Reserved (2 bytes)
      msg.skip(2)
      # Called AE (shall be returned in the association response) (16 bytes)
      info[:called_ae] = msg.decode(16, "STR")
      # Calling AE (shall be returned in the association response) (16 bytes)
      info[:calling_ae] = msg.decode(16, "STR")
      # Reserved (32 bytes)
      msg.skip(32)
      # APPLICATION CONTEXT:
      # Item type (1 byte)
      info[:application_item_type] = msg.decode(1, "HEX") # 10H
      # Reserved (1 byte)
      msg.skip(1)
      # Application item length (2 bytes)
      info[:application_item_length] = msg.decode(2, "US")
      # Application context (variable length)
      info[:application_context] = msg.decode(info[:application_item_length], "STR")
      # PRESENTATION CONTEXT:
      # As multiple presentation contexts may occur, we need a loop to catch them all:
      # Each presentation context hash will be put in an array, which will be put in the info hash.
      presentation_contexts = Array.new
      pc_loop = true
      while pc_loop do
        # Item type (1 byte)
        item_type = msg.decode(1, "HEX")
        if item_type == ITEM_PRESENTATION_CONTEXT_REQUEST
          pc = Hash.new
          pc[:presentation_item_type] = item_type
          # Reserved (1 byte)
          msg.skip(1)
          # Presentation context item length (2 bytes)
          pc[:presentation_item_length] = msg.decode(2, "US")
          # Presentation context id (1 byte)
          pc[:presentation_context_id] = msg.decode(1, "BY")
          # Reserved (3 bytes)
          msg.skip(3)
          presentation_contexts << pc
          # A presentation context contains an abstract syntax and one or more transfer syntaxes.
          # ABSTRACT SYNTAX SUB-ITEM:
          # Abstract syntax item type (1 byte)
          pc[:abstract_syntax_item_type] = msg.decode(1, "HEX")
          # Reserved (1 byte)
          msg.skip(1)
          # Abstract syntax item length (2 bytes)
          pc[:abstract_syntax_item_length] = msg.decode(2, "US")
          # Abstract syntax (variable length)
          pc[:abstract_syntax] = msg.decode(pc[:abstract_syntax_item_length], "STR")
          ## TRANSFER SYNTAX SUB-ITEM(S):
          # As multiple transfer syntaxes may occur, we need a loop to catch them all:
          # Each transfer syntax hash will be put in an array, which will be put in the presentation context hash.
          transfer_syntaxes = Array.new
          ts_loop = true
          while ts_loop do
            # Item type (1 byte)
            item_type = msg.decode(1, "HEX")
            if item_type == ITEM_TRANSFER_SYNTAX
              ts = Hash.new
              ts[:transfer_syntax_item_type] = item_type
              # Reserved (1 byte)
              msg.skip(1)
              # Transfer syntax item length (2 bytes)
              ts[:transfer_syntax_item_length] = msg.decode(2, "US")
              # Transfer syntax name (variable length)
              ts[:transfer_syntax] = msg.decode(ts[:transfer_syntax_item_length], "STR")
              transfer_syntaxes << ts
            else
              # Break the transfer syntax loop, as we have probably reached the next stage,
              # which is either user info or a new presentation context entry. Rewind:
              msg.skip(-1)
              ts_loop = false
            end
          end
          pc[:ts] = transfer_syntaxes
        else
          # Break the presentation context loop, as we have probably reached the next stage, which is user info. Rewind:
          msg.skip(-1)
          pc_loop = false
        end
      end
      info[:pc] = presentation_contexts
      # USER INFORMATION:
      # Item type (1 byte)
      info[:user_info_item_type] = msg.decode(1, "HEX")
      # Reserved (1 byte)
      msg.skip(1)
      # User information item length (2 bytes)
      info[:user_info_item_length] = msg.decode(2, "US")
      # User data (variable length):
      while msg.index < msg.length do
        # Item type (1 byte)
        item_type = msg.decode(1, "HEX")
        # Reserved (1 byte)
        msg.skip(1)
        # Item length (2 bytes)
        item_length = msg.decode(2, "US")
        case item_type
          when ITEM_MAX_LENGTH
            info[:max_pdu_length] = msg.decode(item_length, "UL")
          when ITEM_IMPLEMENTATION_UID
            info[:implementation_class_uid] = msg.decode(item_length, "STR")
          when ITEM_MAX_OPERATIONS_INVOKED
            # Asynchronous operations window negotiation (PS 3.7: D.3.3.3) (2*2 bytes)
            info[:maxnum_operations_invoked] = msg.decode(2, "US")
            info[:maxnum_operations_performed] = msg.decode(2, "US")
          when ITEM_ROLE_NEGOTIATION
            # SCP/SCU Role Selection Negotiation (PS 3.7 D.3.3.4)
            # Note: An association request may contain several instances of this item type (each with a different abstract syntax).
            uid_length = msg.decode(2, "US")
            role = Hash.new
            # SOP Class UID (Abstract syntax):
            role[:sop_uid] = msg.decode(uid_length, "STR")
            # SCU Role (1 byte):
            role[:scu] = msg.decode(1, "BY")
            # SCP Role (1 byte):
            role[:scp] = msg.decode(1, "BY")
            if info[:role_negotiation]
              info[:role_negotiation] << role
            else
              info[:role_negotiation] = [role]
            end
          when ITEM_IMPLEMENTATION_VERSION
            info[:implementation_version] = msg.decode(item_length, "STR")
          else
            # Unknown item type:
            # Value (variable length)
            value = msg.decode(item_length, "STR")
            add_error("Notice: Unknown user info item type received. Please update source code or contact author. (item type: " + item_type + ")")
        end
      end
      stop_receiving
      info[:valid] = true
      return info
    end

    # Decodes the received command/data binary string, and interprets its content.
    # Decoding of data fragment will depend on the explicitness of the transmission.
    #
    def interpret_command_and_data(message, file=nil)
      info = Hash.new
      msg = Stream.new(message, @net_endian)
      # Length (of remaining PDV data) (4 bytes)
      info[:presentation_data_value_length] = msg.decode(4, "UL")
      # Calculate the last index position of this message element:
      last_index = info[:presentation_data_value_length] + msg.index
      # Presentation context ID (1 byte)
      info[:presentation_context_id] = msg.decode(1, "BY")
      @presentation_context_id = info[:presentation_context_id]
      # Flags (1 byte)
      info[:presentation_context_flag] = msg.decode(1, "HEX") # "03" for command (last fragment), "02" for data
      # Apply the proper transfer syntax for this presentation context:
      set_transfer_syntax(@presentation_contexts[info[:presentation_context_id]])
      # "Data endian" encoding from now on:
      msg.set_endian(@data_endian)
      # We will put the results in a hash:
      results = Hash.new
      if info[:presentation_context_flag] == COMMAND_LAST_FRAGMENT
        # COMMAND, LAST FRAGMENT:
        while msg.index < last_index do
          # Tag (4 bytes)
          tag = msg.decode_tag
          # Length (2 bytes)
          length = msg.decode(2, "US")
          if length > msg.rest_length
            add_error("Error: Specified length of command element value exceeds remaining length of the received message! Something is wrong.")
          end
          # Reserved (2 bytes)
          msg.skip(2)
          # Type (VR) (from library - not the stream):
          result = LIBRARY.get_name_vr(tag)
          name = result[0]
          type = result[1]
          # Value (variable length)
          value = msg.decode(length, type)
          # Put tag and value in a hash:
          results[tag] = value
        end
        # The results hash is put in an array along with (possibly) other results:
        info[:results] = results
        # Store the results in an instance variable (to be used later when sending a receipt for received data):
        @command_request = results
        # Check if the command fragment indicates that this was the last of the response fragments for this query:
        status = results["0000,0900"]
        if status
          # Note: This method will also stop the packet receiver if indicated by the status mesasge.
          process_status(status)
        end
        # Special case: Handle a possible C-ECHO-RQ:
        if info[:results]["0000,0100"] == C_ECHO_RQ
          add_notice("Received an Echo request. Returning an Echo response.")
          handle_response
        end
      elsif info[:presentation_context_flag] == DATA_MORE_FRAGMENTS or info[:presentation_context_flag] == DATA_LAST_FRAGMENT
        # DATA FRAGMENT:
        # If this is a file transmission, we will delay the decoding for later:
        if file
          # Just store the binary string:
          info[:bin] = msg.rest_string
          # If this was the last data fragment of a C-STORE, we need to send a receipt:
          # (However, for, say a C-FIND-RSP, which indicates the end of the query results, this method shall not be called) (Command Field (0000,0100) holds information on this)
          handle_response if info[:presentation_context_flag] == DATA_LAST_FRAGMENT
        else
          # Decode data elements:
          while msg.index < last_index do
            # Tag (4 bytes)
            tag = msg.decode_tag
            if @explicit
              # Type (VR) (2 bytes):
              type = msg.decode(2, "STR")
              # Length (2 bytes)
              length = msg.decode(2, "US")
            else
              # Implicit:
              type = nil # (needs to be defined as nil here or it will take the value from the previous step in the loop)
              # Length (4 bytes)
              length = msg.decode(4, "UL")
            end
            if length > msg.rest_length
              add_error("Error: Specified length of data element value exceeds remaining length of the received message! Something is wrong.")
            end
            # Fetch the name (& type if not defined already) for this data element:
            result = LIBRARY.get_name_vr(tag)
            name = result[0]
            type = result[1] unless type
            # Value (variable length)
            value = msg.decode(length, type)
            # Put tag and value in a hash:
            results[tag] = value
          end
          # The results hash is put in an array along with (possibly) other results:
          info[:results] = results
        end
      else
        # Unknown.
        add_error("Error: Unknown presentation context flag received in the query/command response. (#{info[:presentation_context_flag]})")
        stop_receiving
      end
      # If only parts of the string was read, return the rest:
      info[:rest_string] = msg.rest_string if last_index < msg.length
      info[:valid] = true
      return info
    end

    # Decodes the binary string received in the release request, and completes the release by returning a release response.
    #
    def interpret_release_request(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian)
      # Reserved (4 bytes)
      reserved_bytes = msg.decode(4, "HEX")
      handle_release
      info[:valid] = true
      return info
    end

    # Decodes the binary string received in the release response, and interprets its content.
    #
    def interpret_release_response(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian)
      # Reserved (4 bytes)
      reserved_bytes = msg.decode(4, "HEX")
      stop_receiving
      info[:valid] = true
      return info
    end

    # Handles multiple incoming transmissions and returns the interpreted, received data.
    #
    def receive_multiple_transmissions(file=nil)
      @listen = true
      segments = Array.new
      while @listen
        # Receive data and append the current data to our segments array, which will be returned.
        data = receive_transmission(@min_length)
        current_segments = interpret(data, file)
        if current_segments
          current_segments.each do |cs|
            segments << cs
          end
        end
      end
      segments << {:valid => false} unless segments
      return segments
    end

    # Handles an expected single incoming transmission and returns the interpreted, received data.
    #
    def receive_single_transmission
      min_length = 8
      data = receive_transmission(min_length)
      segments = interpret(data)
      segments << {:valid => false} unless segments.length > 0
      return segments
    end

    # Sets the session of this Link instance (used when this session is already established externally).
    #
    def set_session(session)
      @session = session
    end

    # Establishes a new session with a remote network host, using the specified adress and port.
    #
    def start_session(adress, port)
      @session = TCPSocket.new(adress, port)
    end

    # Ends the current session.
    #
    def stop_session
      @session.close unless @session.closed?
    end

    # Sends the encoded binary string (package) to its destination.
    #
    def transmit
      @session.send(@outgoing.string, 0)
    end


    # Following methods are private:
    private


    # Adds a warning or error message to the instance array holding messages,
    # and if verbose variable is true, prints the message as well.
    #
    def add_error(error)
      puts error if @verbose
      @errors << error
    end

    # Adds a notice (information regarding progress or successful communications) to the instance array,
    # and if verbosity is set for these kinds of messages, prints it to the screen as well.
    #
    def add_notice(notice)
      puts notice if @verbose
      @notices << notice
    end

    # Builds the application context that is part of the association request.
    #
    def append_application_context(ac_uid)
      # Application context item type (1 byte)
      @outgoing.encode_last(ITEM_APPLICATION_CONTEXT, "HEX")
      # Reserved (1 byte)
      @outgoing.encode_last("00", "HEX")
      # Application context item length (2 bytes)
      @outgoing.encode_last(ac_uid.length, "US")
      # Application context (variable length)
      @outgoing.encode_last(ac_uid, "STR")
    end

    # Builds the binary string that makes up the header part (part of the association request).
    #
    def append_association_header(pdu, called_ae)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Header will be encoded in opposite order, where the elements are being put first in the outgoing binary string.
      # Build last part of header first. This is necessary to be able to assess the length value.
      # Reserved (32 bytes)
      @outgoing.encode_first("00"*32, "HEX")
      # Calling AE title (16 bytes)
      calling_ae = @outgoing.encode_string_with_trailing_spaces(@ae, 16)
      @outgoing.add_first(calling_ae) # (pre-encoded value)
      # Called AE title (16 bytes) (return the name that the SCU used in the association request)
      formatted_called_ae = @outgoing.encode_string_with_trailing_spaces(called_ae, 16)
      @outgoing.add_first(formatted_called_ae) # (pre-encoded value)
      # Reserved (2 bytes)
      @outgoing.encode_first("0000", "HEX")
      # Protocol version (2 bytes)
      @outgoing.encode_first("0001", "HEX")
      append_header(pdu)
    end

    # Adds the header bytes to the outgoing, binary string (this part has the same structure for all dicom network messages)
    #
    def append_header(pdu)
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # Reserved (1 byte)
      @outgoing.encode_first("00", "HEX")
      # PDU type (1 byte)
      @outgoing.encode_first(pdu, "HEX")
    end

    # Builds the binary string that makes up the presentation context part (part of the association request/accept).
    # Description of error codes are given in the DICOM Standard, PS 3.8, Chapter 9.3.3.2 (Table 9-18).
    #
    def append_presentation_contexts(abstract_syntaxes, pc, ts, context_id=nil, result=ACCEPTANCE)
      # One presentation context for each abstract syntax:
      abstract_syntaxes.each_with_index do |as, index|
        # PRESENTATION CONTEXT:
        # Presentation context item type (1 byte)
        @outgoing.encode_last(pc, "HEX")
        # Reserved (1 byte)
        @outgoing.encode_last("00", "HEX")
        # Presentation context item length (2 bytes)
        if ts.is_a?(Array)
          ts_length = 4*ts.length + ts.join.length
        else # (String)
          ts_length = 4 + ts.length
        end
        if as
          items_length = 4 + (4 + as.length) + ts_length
        else
          items_length = 4 + ts_length
        end
        @outgoing.encode_last(items_length, "US")
        # Presentation context ID (1 byte)
        # Generate a number based on the index of the abstract syntax, unless one has been supplied to this method already.
        # (NB! This number should be odd, and in the range 1..255)
        if context_id
          presentation_context_id = context_id
        else
          presentation_context_id = index*2 + 1
        end
        @outgoing.encode_last(presentation_context_id, "BY")
        # Reserved (1 byte)
        @outgoing.encode_last("00", "HEX")
        # (1 byte) Reserved (for association request) & Result/reason (for association accept response)
        @outgoing.encode_last(result, "BY")
        # Reserved (1 byte)
        @outgoing.encode_last("00", "HEX")
        ## ABSTRACT SYNTAX SUB-ITEM: (only for request, not response)
        if as
          # Abstract syntax item type (1 byte)
          @outgoing.encode_last(ITEM_ABSTRACT_SYNTAX, "HEX")
          # Reserved (1 byte)
          @outgoing.encode_last("00", "HEX")
          # Abstract syntax item length (2 bytes)
          @outgoing.encode_last(as.length, "US")
          # Abstract syntax (variable length)
          @outgoing.encode_last(as, "STR")
        end
        ## TRANSFER SYNTAX SUB-ITEM (not included if result indicates error):
        if result == ACCEPTANCE
          ts = [ts] if ts.is_a?(String)
          ts.each do |t|
            # Transfer syntax item type (1 byte)
            @outgoing.encode_last(ITEM_TRANSFER_SYNTAX, "HEX")
            # Reserved (1 byte)
            @outgoing.encode_last("00", "HEX")
            # Transfer syntax item length (2 bytes)
            @outgoing.encode_last(t.length, "US")
            # Transfer syntax (variable length)
            @outgoing.encode_last(t, "STR")
          end
        end
      end
    end

    # Adds the binary string that makes up the user information (part of the association request).
    #
    def append_user_information(ui)
      # USER INFORMATION:
      # User information item type (1 byte)
      @outgoing.encode_last(ITEM_USER_INFORMATION, "HEX")
      # Reserved (1 byte)
      @outgoing.encode_last("00", "HEX")
      # Encode the user information item values so we can determine the remaining length of this section:
      values = Array.new
      ui.each_index do |i|
        values << @outgoing.encode(ui[i][2], ui[i][1])
      end
      # User information item length (2 bytes)
      items_length = 4*ui.length + values.join.length
      @outgoing.encode_last(items_length, "US")
      # SUB-ITEMS:
      ui.each_index do |i|
        # UI item type (1 byte)
        @outgoing.encode_last(ui[i][0], "HEX")
        # Reserved (1 byte)
        @outgoing.encode_last("00", "HEX")
        # UI item length (2 bytes)
        @outgoing.encode_last(values[i].length, "US")
        # UI value (4 bytes)
        @outgoing.add_last(values[i])
      end
    end

    # Returns a proper response value for the Command Field (0000,0100) based on a specified request value.
    #
    def command_field_response(request)
      case request
        when C_STORE_RQ
          return C_STORE_RSP
        when C_ECHO_RQ
          return C_ECHO_RSP
        else
          add_error("Unknown or unsupported request (#{request}) encountered.")
          return C_CANCEL_RQ
      end
    end

    # Processes the value of the reason byte (in an association abort).
    # This will provide a description of what is the reason for the error.
    #
    def process_reason(reason)
      case reason
        when "00"
          add_error("Reason specified for abort: Reason not specified")
        when "01"
          add_error("Reason specified for abort: Unrecognized PDU")
        when "02"
          add_error("Reason specified for abort: Unexpected PDU")
        when "04"
          add_error("Reason specified for abort: Unrecognized PDU parameter")
        when "05"
          add_error("Reason specified for abort: Unexpected PDU parameter")
        when "06"
          add_error("Reason specified for abort: Invalid PDU parameter value")
        else
          add_error("Reason specified for abort: Unknown reason (Error code: #{reason})")
      end
    end

    # Processes the value of the result byte (in the association response).
    # Something is wrong if result is different from 0.
    #
    def process_result(result)
      unless result == 0
        # Analyse the result and report what is wrong:
        case result
          when 1
            add_error("Warning: DICOM Request was rejected by the host, reason: 'User-rejection'")
          when 2
            add_error("Warning: DICOM Request was rejected by the host, reason: 'No reason (provider rejection)'")
          when 3
            add_error("Warning: DICOM Request was rejected by the host, reason: 'Abstract syntax not supported'")
          when 4
            add_error("Warning: DICOM Request was rejected by the host, reason: 'Transfer syntaxes not supported'")
          else
            add_error("Warning: DICOM Request was rejected by the host, reason: 'UNKNOWN (#{result})' (Illegal reason provided)")
        end
      end
    end

    # Processes the value of the source byte (in an association abort).
    # This will provide a description of who is the source of the error.
    #
    def process_source(source)
      if source == "00"
        add_error("Warning: Connection has been aborted by the service provider because of an error by the service user (client side).")
      elsif source == "02"
        add_error("Warning: Connection has been aborted by the service provider because of an error by the service provider (server side).")
      else
        add_error("Warning: Connection has been aborted by the service provider, with an unknown cause of the problems. (error code: #{source})")
      end
    end

    # Processes the value of the status tag (0000,0900) received in the command fragment.
    # Note: The status tag has vr 'US', and the status as reported here is therefore a number.
    # In the official DICOM documents however, the value of the various status options is given in hex format.
    # Resources: DICOM PS3.4 Annex Q 2.1.1.4, DICOM PS3.7 Annex C 4.
    #
    def process_status(status)
      case status
        when 0 # "0000"
          # Last fragment (Break the while loop that listens continuously for incoming packets):
          add_notice("Receipt for successful execution of the desired operation has been received.")
          stop_receiving
        when 42752 # "a700"
          # Failure: Out of resources. Related fields: 0000,0902
          add_error("Failure! SCP has given the following reason: 'Out of Resources'.")
        when 43264 # "a900"
          # Failure: Identifier Does Not Match SOP Class. Related fields: 0000,0901, 0000,0902
          add_error("Failure! SCP has given the following reason: 'Identifier Does Not Match SOP Class'.")
        when 49152 # "c000"
          # Failure: Unable to process. Related fields: 0000,0901, 0000,0902
          add_error("Failure! SCP has given the following reason: 'Unable to process'.")
        when 49408 # "c100"
          # Failure: More than one match found. Related fields: 0000,0901, 0000,0902
          add_error("Failure! SCP has given the following reason: 'More than one match found'.")
        when 49664 # "c200"
          # Failure: Unable to support requested template. Related fields: 0000,0901, 0000,0902
          add_error("Failure! SCP has given the following reason: 'Unable to support requested template'.")
        when 65024 # "fe00"
          # Cancel: Matching terminated due to Cancel request.
          add_notice("Cancel! SCP has given the following reason: 'Matching terminated due to Cancel request'.")
        when 65280 # "ff00"
          # Sub-operations are continuing.
          # (No particular action taken, the program will listen for and receive the coming fragments)
        when 65281 # "ff01"
          # More command/data fragments to follow.
          # (No particular action taken, the program will listen for and receive the coming fragments)
        else
          add_error("Error! Something was NOT successful regarding the desired operation. SCP responded with error code: #{status} (tag: 0000,0900). See DICOM PS3.7, Annex C for details.")
      end
    end

    # Handles an incoming transmission.
    # Optional: Specify a minimum length of the incoming transmission. (If a message is received
    # which is shorter than this limit, the method will keep listening for more incoming packets to append)
    #
    def receive_transmission(min_length=0)
      data = receive_transmission_data
      # Check the nature of the received data variable:
      if data
        # Sometimes the incoming transmission may be broken up into smaller pieces:
        # Unless a short answer is expected, we will continue to listen if the first answer was too short:
        unless min_length == 0
          if data.length < min_length
            addition = receive_transmission_data
            data = data + addition if addition
          end
        end
      else
        # It seems there was no incoming message and the operation timed out.
        # Convert the variable to an empty string.
        data = ""
      end
      return data
    end

    # Receives the incoming transmission data.
    #
    def receive_transmission_data
      data = false
      t1 = Time.now.to_f
      @receive = true
      thr = Thread.new{ data = @session.recv(@max_receive_size); @receive = false }
      while @receive
        if (Time.now.to_f - t1) > @timeout
          Thread.kill(thr)
          add_error("No answer was received within the specified timeout period. Aborting.")
          stop_receiving
        end
      end
      return data
    end

    # Sets some default values.
    #
    def set_default_values
      # Default endianness for network transmissions is Big Endian:
      @net_endian = true
      # Default endianness of data is little endian:
      @data_endian = false
      # It may turn out to be unncessary to define the following values at this early stage.
      # Explicitness:
      @explicit = false
      # Transfer syntax:
      set_transfer_syntax(IMPLICIT_LITTLE_ENDIAN)
    end

    # Set instance variables related to the transfer syntax.
    #
    def set_transfer_syntax(value)
      @transfer_syntax = value
      # Query the library with our particular transfer syntax string:
      valid_syntax, @explicit, @data_endian = LIBRARY.process_transfer_syntax(value)
      unless valid_syntax
        add_error("Warning: Invalid/unknown transfer syntax encountered! Will try to continue, but errors may occur.")
      end
    end

    # Sets user information [item type code, vr/type, value].
    #
    def set_user_information_array(info = nil)
      @user_information = [
        [ITEM_MAX_LENGTH, "UL", @max_package_size],
        [ITEM_IMPLEMENTATION_UID, "STR", UID],
        [ITEM_IMPLEMENTATION_VERSION, "STR", NAME]
      ]
      # A bit of a hack to include "asynchronous operations window negotiation" and/or "role negotiation",
      # in cases where this has been included in the association request:
      if info
        if info[:maxnum_operations_invoked]
          @user_information.insert(2, [ITEM_MAX_OPERATIONS_INVOKED, "HEX", "00010001"])
        end
        if info[:role_negotiation]
          pos = 3
          info[:role_negotiation].each do |role|
            msg = Stream.new(message, @net_endian)
            uid = role[:sop_uid]
            # Length of UID (2 bytes):
            msg.encode_first(uid.length, "US")
            # SOP UID being negotiated (Variable length):
            msg.encode_last(uid, "STR")
            # SCU Role (Always accept SCU) (1 byte):
            if role[:scu] == 1
              msg.encode_last(1, "BY")
            else
              msg.encode_last(0, "BY")
            end
            # SCP Role (Never accept SCP) (1 byte):
            if role[:scp] == 1
              msg.encode_last(0, "BY")
            else
              msg.encode_last(1, "BY")
            end
            @user_information.insert(pos, [ITEM_ROLE_NEGOTIATION, "STR", msg.string])
            pos += 1
          end
        end
      end
    end

    # Breaks the loops that listen for incoming packets by changing a couple of instance variables.
    # This method is called by the various methods that interpret incoming data when they have verified that
    # the entire message has been received, or when a timeout is reached.
    #
    def stop_receiving
      @listen = false
      @receive = false
    end

  end # of class
end # of module