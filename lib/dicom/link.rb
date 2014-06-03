module DICOM

  # This class handles the construction and interpretation of network packages
  # as well as network communication.
  #
  class Link
    include Logging

    # A customized FileHandler class to use instead of the default FileHandler included with Ruby DICOM.
    attr_accessor :file_handler
    # The maximum allowed size of network packages (in bytes).
    attr_accessor :max_package_size
    # A hash which keeps track of the relationship between context ID and chosen transfer syntax.
    attr_accessor :presentation_contexts
    # A TCP network session where the DICOM communication is done with a remote host or client.
    attr_reader :session

    # Creates a Link instance, which is used by both DClient and DServer to handle network communication.
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:ae</tt> -- String. The name of the client (application entity).
    # * <tt>:file_handler</tt> -- A customized FileHandler class to use instead of the default FileHandler.
    # * <tt>:host_ae</tt> -- String. The name of the server (application entity).
    # * <tt>:max_package_size</tt> -- Fixnum. The maximum allowed size of network packages (in bytes).
    # * <tt>:timeout</tt> -- Fixnum. The maximum period to wait for an answer before aborting the communication.
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

    # Waits for an SCU to issue a release request, and answers it by launching the handle_release method.
    # If invalid or no message is received, the connection is closed.
    #
    def await_release
      segments = receive_single_transmission
      info = segments.first
      if info[:pdu] != PDU_RELEASE_REQUEST
        # For some reason we didn't get our expected release request. Determine why:
        if info[:valid]
          logger.error("Unexpected message type received (PDU: #{info[:pdu]}). Expected a release request. Closing the connection.")
          handle_abort(false)
        else
          logger.error("Timed out while waiting for a release request. Closing the connection.")
        end
        stop_session
      else
        # Properly release the association:
        handle_release
      end
    end

    # Builds the abort message which is transmitted when the server wishes to (abruptly) abort the connection.
    #
    # === Restrictions
    #
    # For now, no reasons for the abortion are provided (and source of problems will always be set as client side).
    #
    def build_association_abort
      # Big endian encoding:
      @outgoing.endian = @net_endian
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

    # Builds the binary string which is sent as the association accept (in response to an association request).
    #
    # === Parameters
    #
    # * <tt>info</tt> -- The association information hash.
    #
    def build_association_accept(info)
      # Big endian encoding:
      @outgoing.endian = @net_endian
      # Clear the outgoing binary string:
      @outgoing.reset
      # No abstract syntax in association response. To make this work with the method that
      # encodes the presentation context, we pass on a one-element array containing nil).
      abstract_syntaxes = Array.new(1, nil)
      # Note: The order of which these components are built is not arbitrary.
      append_application_context
      # Reset the presentation context instance variable:
      @presentation_contexts = Hash.new
      # Create the presentation context hash object that will be passed to the builder method:
      p_contexts = Hash.new
      # Build the presentation context strings, one by one:
      info[:pc].each do |pc|
        @presentation_contexts[pc[:presentation_context_id]] = pc[:selected_transfer_syntax]
        # Add the information from this pc item to the p_contexts hash:
        p_contexts[pc[:abstract_syntax]] = Hash.new unless p_contexts[pc[:abstract_syntax]]
        p_contexts[pc[:abstract_syntax]][pc[:presentation_context_id]] = {:transfer_syntaxes => [pc[:selected_transfer_syntax]], :result => pc[:result]}
      end
      append_presentation_contexts(p_contexts, ITEM_PRESENTATION_CONTEXT_RESPONSE)
      append_user_information(@user_information)
      # Header must be built last, because we need to know the length of the other components.
      append_association_header(PDU_ASSOCIATION_ACCEPT, info[:called_ae])
    end

    # Builds the binary string which is sent as the association reject (in response to an association request).
    #
    # === Parameters
    #
    # * <tt>info</tt> -- The association information hash.
    #
    # === Restrictions
    #
    # * For now, this method will only customize the "reason" value.
    # * For a list of error codes, see the DICOM standard, PS3.8 Chapter 9.3.4, Table 9-21.
    #
    def build_association_reject(info)
      # Big endian encoding:
      @outgoing.endian = @net_endian
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

    # Builds the binary string which is sent as the association request.
    #
    # === Parameters
    #
    # * <tt>presentation_contexts</tt> -- A hash containing abstract_syntaxes, presentation context ids and transfer syntaxes.
    # * <tt>user_info</tt> -- A user information items array.
    #
    def build_association_request(presentation_contexts, user_info)
      # Big endian encoding:
      @outgoing.endian = @net_endian
      # Clear the outgoing binary string:
      @outgoing.reset
      # Note: The order of which these components are built is not arbitrary.
      # (The first three are built 'in order of appearance', the header is built last, but is put first in the message)
      append_application_context
      append_presentation_contexts(presentation_contexts, ITEM_PRESENTATION_CONTEXT_REQUEST, request=true)
      append_user_information(user_info)
      # Header must be built last, because we need to know the length of the other components.
      append_association_header(PDU_ASSOCIATION_REQUEST, @host_ae)
    end

    # Builds the binary string which is sent as a command fragment.
    #
    # === Parameters
    #
    # * <tt>pdu</tt> -- The command fragment's PDU string.
    # * <tt>context</tt> -- Presentation context ID byte (references a presentation context from the association).
    # * <tt>flags</tt> -- The flag string, which identifies if this is the last command fragment or not.
    # * <tt>command_elements</tt> -- An array of command elements.
    #
    def build_command_fragment(pdu, context, flags, command_elements)
      # Little endian encoding:
      @outgoing.endian = @data_endian
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
      @outgoing.endian = @net_endian
      # Flags (1 byte)
      @outgoing.encode_first(flags, "HEX")
      # Presentation context ID (1 byte)
      @outgoing.encode_first(context, "BY")
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(pdu)
    end

    # Builds the binary string which is sent as a data fragment.
    #
    # === Notes
    #
    # * The style of encoding will depend on whether we have an implicit or explicit transfer syntax.
    #
    # === Parameters
    #
    # * <tt>data_elements</tt> -- An array of data elements.
    # * <tt>presentation_context_id</tt> -- Presentation context ID byte (references a presentation context from the association).
    #
    def build_data_fragment(data_elements, presentation_context_id)
      # Set the transfer syntax to be used for encoding the data fragment:
      set_transfer_syntax(@presentation_contexts[presentation_context_id])
      # Endianness of data fragment:
      @outgoing.endian = @data_endian
      # Clear the outgoing binary string:
      @outgoing.reset
      # Build the last part first, the Data items:
      data_elements.each do |element|
        # Encode all tags (even tags which are empty):
        # Tag (4 bytes)
        @outgoing.add_last(@outgoing.encode_tag(element[0]))
        # Encode the value in advance of putting it into the message, so we know its length:
        vr = LIBRARY.element(element[0]).vr
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
      @outgoing.endian = @net_endian
      # Flags (1 byte)
      @outgoing.encode_first("02", "HEX") # Data, last fragment (identifier)
      # Presentation context ID (1 byte)
      @outgoing.encode_first(presentation_context_id, "BY")
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(PDU_DATA)
    end

    # Builds the binary string which is sent as the release request.
    #
    def build_release_request
      # Big endian encoding:
      @outgoing.endian = @net_endian
      # Clear the outgoing binary string:
      @outgoing.reset
      # Reserved (4 bytes)
      @outgoing.encode_last("00"*4, "HEX")
      append_header(PDU_RELEASE_REQUEST)
    end

    # Builds the binary string which is sent as the release response (which follows a release request).
    #
    def build_release_response
      # Big endian encoding:
      @outgoing.endian = @net_endian
      # Clear the outgoing binary string:
      @outgoing.reset
      # Reserved (4 bytes)
      @outgoing.encode_last("00000000", "HEX")
      append_header(PDU_RELEASE_RESPONSE)
    end

    # Builds the binary string which makes up a C-STORE data fragment.
    #
    # === Parameters
    #
    # * <tt>pdu</tt> -- The data fragment's PDU string.
    # * <tt>context</tt> -- Presentation context ID byte (references a presentation context from the association).
    # * <tt>flags</tt> -- The flag string, which identifies if this is the last data fragment or not.
    # * <tt>body</tt> -- A pre-encoded binary string (typicall a segment of a DICOM file to be transmitted).
    #
    def build_storage_fragment(pdu, context, flags, body)
      # Big endian encoding:
      @outgoing.endian = @net_endian
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

    # Delegates an incoming message to its appropriate interpreter method, based on its pdu type.
    # Returns the interpreted information hash.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
    # * <tt>pdu</tt> -- The PDU string of the message.
    # * <tt>file</tt> -- A boolean used to inform whether an incoming data fragment is part of a DICOM file reception or not.
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
          logger.error("An unknown PDU type was received in the incoming transmission. Can not decode this message. (PDU: #{pdu})")
      end
      return info
    end

    # Handles the abortion of a session, when a non-valid or unexpected message has been received.
    #
    # === Parameters
    #
    # * <tt>default_message</tt> -- A boolean which unless set as nil/false will make the method print the default status message.
    #
    def handle_abort(default_message=true)
      logger.warn("An unregonizable (non-DICOM) message was received.") if default_message
      build_association_abort
      transmit
    end

    # Handles the outgoing association accept message.
    #
    # === Parameters
    #
    # * <tt>info</tt> -- The association information hash.
    #
    def handle_association_accept(info)
      # Update the variable for calling ae (information gathered in the association request):
      @ae = info[:calling_ae]
      # Build message string and send it:
      set_user_information_array(info)
      build_association_accept(info)
      transmit
    end

    # Processes incoming command & data fragments for the DServer.
    # Returns a success boolean and an array of status messages.
    #
    # === Notes
    #
    # The incoming traffic will in most cases be: A C-STORE-RQ (command fragment) followed by a bunch of data fragments.
    # However, it may also be a C-ECHO-RQ command fragment, which is used to test connections.
    #
    # === Parameters
    #
    # * <tt>path</tt> -- The path used to save incoming DICOM files.
    #
    #--
    # FIXME: The code which handles incoming data isnt quite satisfactory. It would probably be wise to rewrite it at some stage to clean up
    # the code somewhat. Probably a better handling of command requests (and their corresponding data fragments) would be a good idea.
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

    # Handles the rejection message (The response used to an association request when its formalities are not correct).
    #
    def handle_rejection
      logger.warn("An incoming association request was rejected. Error code: #{association_error}")
      # Insert the error code in the info hash:
      info[:reason] = association_error
      # Send an association rejection:
      build_association_reject(info)
      transmit
    end

    # Handles the release message (which is the response to a release request).
    #
    def handle_release
      stop_receiving
      logger.info("Received a release request. Releasing association.")
      build_release_response
      transmit
      stop_session
    end

    # Handles the command fragment response.
    #
    # === Notes
    #
    # This is usually a C-STORE-RSP which follows the (successful) reception of a DICOM file, but may also
    # be a C-ECHO-RSP in response to an echo request.
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

    # Decodes the header of an incoming message, analyzes its real length versus expected length, and handles any
    # deviations to make sure that message strings are split up appropriately before they are being forwarded to interpretation.
    # Returns an array of information hashes.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
    # * <tt>file</tt> -- A boolean used to inform whether an incoming data fragment is part of a DICOM file reception or not.
    #
    #--
    # FIXME: This method is rather complex and doesnt feature the best readability. A rewrite that is able to simplify it would be lovely.
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
          #logger.error("Error. The length of the received message (#{msg.rest_length}) is smaller than what it claims (#{specified_length}). Aborting.")
          @first_part = msg.string
        end
      else
        # Assume that this is only the start of the message, and add it to the next incoming string:
        @first_part = message
      end
      return segments
    end

    # Decodes the message received when the remote node wishes to abort the session.
    # Returns the processed information hash.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
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

    # Decodes the message received in the association response, and interprets its content.
    # Returns the processed information hash.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
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
            logger.warn("Unknown user info item type received. Please update source code or contact author. (item type: #{item_type})")
        end
      end
      stop_receiving
      info[:valid] = true
      return info
    end

    # Decodes the association reject message and extracts the error reasons given.
    # Returns the processed information hash.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
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
      logger.warn("ASSOCIATE Request was rejected by the host. Error codes: Result: #{info[:result]}, Source: #{info[:source]}, Reason: #{info[:reason]} (See DICOM PS3.8: Table 9-21 for details.)")
      stop_receiving
      info[:valid] = true
      return info
    end

    # Decodes the binary string received in the association request, and interprets its content.
    # Returns the processed information hash.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
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
            logger.warn("Unknown user info item type received. Please update source code or contact author. (item type: " + item_type + ")")
        end
      end
      stop_receiving
      info[:valid] = true
      return info
    end

    # Decodes the received command/data fragment message, and interprets its content.
    # Returns the processed information hash.
    #
    # === Notes
    #
    # * Decoding of a data fragment depends on the explicitness of the transmission.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
    # * <tt>file</tt> -- A boolean used to inform whether an incoming data fragment is part of a DICOM file reception or not.
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
      msg.endian = @data_endian
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
            logger.error("Specified length of command element value exceeds remaining length of the received message! Something is wrong.")
          end
          # Reserved (2 bytes)
          msg.skip(2)
          # VR (from library - not the stream):
          vr = LIBRARY.element(tag).vr
          # Value (variable length)
          value = msg.decode(length, vr)
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
          logger.info("Received an Echo request. Returning an Echo response.")
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
              logger.error("The specified length of the data element value exceeds the remaining length of the received message!")
            end
            # Fetch type (if not defined already) for this data element:
            type = LIBRARY.element(tag).vr unless type
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
        logger.error("Unknown presentation context flag received in the query/command response. (#{info[:presentation_context_flag]})")
        stop_receiving
      end
      # If only parts of the string was read, return the rest:
      info[:rest_string] = msg.rest_string if last_index < msg.length
      info[:valid] = true
      return info
    end

    # Decodes the message received in the release request and calls the handle_release method.
    # Returns the processed information hash.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
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

    # Decodes the message received in the release response and closes the connection.
    # Returns the processed information hash.
    #
    # === Parameters
    #
    # * <tt>message</tt> -- The binary message string.
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

    # Handles the reception of multiple incoming transmissions.
    # Returns an array of interpreted message information hashes.
    #
    # === Parameters
    #
    # * <tt>file</tt> -- A boolean used to inform whether an incoming data fragment is part of a DICOM file reception or not.
    #
    def receive_multiple_transmissions(file=nil)
      # FIXME: The code which waits for incoming network packets seems to be very CPU intensive.
      # Perhaps there is a more elegant way to wait for incoming messages?
      #
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

    # Handles the reception of a single, expected incoming transmission and returns the interpreted, received data.
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
    # === Parameters
    #
    # * <tt>session</tt> -- A TCP network connection that has been established with a remote node.
    #
    def set_session(session)
      @session = session
    end

    # Establishes a new session with a remote network node.
    #
    # === Parameters
    #
    # * <tt>adress</tt> -- String. The adress (IP) of the remote node.
    # * <tt>port</tt> -- Fixnum. The network port to be used in the network communication.
    #
    def start_session(adress, port)
      @session = TCPSocket.new(adress, port)
    end

    # Ends the current session by closing the connection.
    #
    def stop_session
      @session.close unless @session.closed?
    end

    # Sends the outgoing message (encoded binary string) to the remote node.
    #
    def transmit
      @session.send(@outgoing.string, 0)
    end


    private


    # Builds the application context (which is part of the association request/response).
    #
    def append_application_context
      # Application context item type (1 byte)
      @outgoing.encode_last(ITEM_APPLICATION_CONTEXT, "HEX")
      # Reserved (1 byte)
      @outgoing.encode_last("00", "HEX")
      # Application context item length (2 bytes)
      @outgoing.encode_last(APPLICATION_CONTEXT.length, "US")
      # Application context (variable length)
      @outgoing.encode_last(APPLICATION_CONTEXT, "STR")
    end

    # Builds the binary string that makes up the header part the association request/response.
    #
    # === Parameters
    #
    # * <tt>pdu</tt> -- The command fragment's PDU string.
    # * <tt>called_ae</tt> -- Application entity (name) of the SCP (host).
    #
    def append_association_header(pdu, called_ae)
      # Big endian encoding:
      @outgoing.endian = @net_endian
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

    # Adds the header bytes to the outgoing message (the header structure is equal for all of the message types).
    #
    # === Parameters
    #
    # * <tt>pdu</tt> -- The command fragment's PDU string.
    #
    def append_header(pdu)
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # Reserved (1 byte)
      @outgoing.encode_first("00", "HEX")
      # PDU type (1 byte)
      @outgoing.encode_first(pdu, "HEX")
    end

    # Builds the binary string that makes up the presentation context part of the association request/accept.
    #
    # === Notes
    #
    # * The values of the parameters will differ somewhat depending on whether this is related to a request or response.
    # * Description of error codes are given in the DICOM Standard, PS 3.8, Chapter 9.3.3.2 (Table 9-18).
    #
    # === Parameters
    #
    # * <tt>presentation_contexts</tt> -- A nested hash object with abstract syntaxes, presentation context ids, transfer syntaxes and result codes.
    # * <tt>item_type</tt> -- Presentation context item (request or response).
    # * <tt>request</tt> -- Boolean. If true, an ossociate request message is generated, if false, an asoociate accept message is generated.
    #
    def append_presentation_contexts(presentation_contexts, item_type, request=false)
      # Iterate the abstract syntaxes:
      presentation_contexts.each_pair do |abstract_syntax, context_ids|
        # Iterate the context ids:
        context_ids.each_pair do |context_id, syntax|
          # PRESENTATION CONTEXT:
          # Presentation context item type (1 byte)
          @outgoing.encode_last(item_type, "HEX")
          # Reserved (1 byte)
          @outgoing.encode_last("00", "HEX")
          # Presentation context item length (2 bytes)
          ts_length = 4*syntax[:transfer_syntaxes].length + syntax[:transfer_syntaxes].join.length
          # Abstract syntax item only included in requests, not accepts:
          items_length = 4 + ts_length
          items_length += 4 + abstract_syntax.length if request
          @outgoing.encode_last(items_length, "US")
          # Presentation context ID (1 byte)
          @outgoing.encode_last(context_id, "BY")
          # Reserved (1 byte)
          @outgoing.encode_last("00", "HEX")
          # (1 byte) Reserved (for association request) & Result/reason (for association accept response)
          result = (syntax[:result] ? syntax[:result] : 0)
          @outgoing.encode_last(result, "BY")
          # Reserved (1 byte)
          @outgoing.encode_last("00", "HEX")
          ## ABSTRACT SYNTAX SUB-ITEM: (only for request, not response)
          if request
            # Abstract syntax item type (1 byte)
            @outgoing.encode_last(ITEM_ABSTRACT_SYNTAX, "HEX")
            # Reserved (1 byte)
            @outgoing.encode_last("00", "HEX")
            # Abstract syntax item length (2 bytes)
            @outgoing.encode_last(abstract_syntax.length, "US")
            # Abstract syntax (variable length)
            @outgoing.encode_last(abstract_syntax, "STR")
          end
          ## TRANSFER SYNTAX SUB-ITEM (not included if result indicates error):
          if result == ACCEPTANCE
            syntax[:transfer_syntaxes].each do |t|
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
    end

    # Adds the binary string that makes up the user information part of the association request/response.
    #
    # === Parameters
    #
    # * <tt>ui</tt> -- User information items array.
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

    # Returns the appropriate response value for the Command Field (0000,0100) to be used in a command fragment (response).
    #
    # === Parameters
    #
    # * <tt>request</tt> -- The Command Field value in a command fragment (request).
    #
    def command_field_response(request)
      case request
        when C_STORE_RQ
          return C_STORE_RSP
        when C_ECHO_RQ
          return C_ECHO_RSP
        else
          logger.error("Unknown or unsupported request (#{request}) encountered.")
          return C_CANCEL_RQ
      end
    end

    # Processes the value of the reason byte received in the association abort, and prints an explanation of the error.
    #
    # === Parameters
    #
    # * <tt>reason</tt> -- String. Reason code for an error that has occured.
    #
    def process_reason(reason)
      case reason
        when "00"
          logger.error("Reason specified for abort: Reason not specified")
        when "01"
          logger.error("Reason specified for abort: Unrecognized PDU")
        when "02"
          logger.error("Reason specified for abort: Unexpected PDU")
        when "04"
          logger.error("Reason specified for abort: Unrecognized PDU parameter")
        when "05"
          logger.error("Reason specified for abort: Unexpected PDU parameter")
        when "06"
          logger.error("Reason specified for abort: Invalid PDU parameter value")
        else
          logger.error("Reason specified for abort: Unknown reason (Error code: #{reason})")
      end
    end

    # Processes the value of the result byte received in the association response.
    # Prints an explanation if an error is indicated.
    #
    # === Notes
    #
    # A value other than 0 indicates an error.
    #
    # === Parameters
    #
    # * <tt>result</tt> -- Fixnum. The result code from an association response.
    #
    def process_result(result)
      unless result == 0
        # Analyse the result and report what is wrong:
        case result
          when 1
            logger.warn("DICOM Request was rejected by the host, reason: 'User-rejection'")
          when 2
            logger.warn("DICOM Request was rejected by the host, reason: 'No reason (provider rejection)'")
          when 3
            logger.warn("DICOM Request was rejected by the host, reason: 'Abstract syntax not supported'")
          when 4
            logger.warn("DICOM Request was rejected by the host, reason: 'Transfer syntaxes not supported'")
          else
            logger.warn("DICOM Request was rejected by the host, reason: 'UNKNOWN (#{result})' (Illegal reason provided)")
        end
      end
    end

    # Processes the value of the source byte in the association abort, and prints an explanation of the source (of the error).
    #
    # === Parameters
    #
    # * <tt>source</tt> -- String. A code which informs which part has been the source of an error.
    #
    def process_source(source)
      if source == "00"
        logger.warn("Connection has been aborted by the service provider because of an error by the service user (client side).")
      elsif source == "02"
        logger.warn("Connection has been aborted by the service provider because of an error by the service provider (server side).")
      else
        logger.warn("Connection has been aborted by the service provider, with an unknown cause of the problems. (error code: #{source})")
      end
    end

    # Processes the value of the status element (0000,0900) received in the command fragment.
    # Prints an explanation where deemed appropriate.
    #
    # === Notes
    #
    # The status element has vr 'US', and the status as reported here is therefore a number.
    # In the official DICOM documents however, the values of the various status options are given in hex format.
    # Resources: The DICOM standard; PS3.4, Annex Q 2.1.1.4 & PS3.7 Annex C 4.
    #
    # === Parameters
    #
    # * <tt>status</tt> -- Fixnum. A status code from a command fragment.
    #
    def process_status(status)
      case status
        when 0 # "0000"
          # Last fragment (Break the while loop that listens continuously for incoming packets):
          logger.info("Receipt for successful execution of the desired operation has been received.")
          stop_receiving
        when 42752 # "a700"
          # Failure: Out of resources. Related fields: 0000,0902
          logger.error("Failure! SCP has given the following reason: 'Out of Resources'.")
        when 43264 # "a900"
          # Failure: Identifier Does Not Match SOP Class. Related fields: 0000,0901, 0000,0902
          logger.error("Failure! SCP has given the following reason: 'Identifier Does Not Match SOP Class'.")
        when 49152 # "c000"
          # Failure: Unable to process. Related fields: 0000,0901, 0000,0902
          logger.error("Failure! SCP has given the following reason: 'Unable to process'.")
        when 49408 # "c100"
          # Failure: More than one match found. Related fields: 0000,0901, 0000,0902
          logger.error("Failure! SCP has given the following reason: 'More than one match found'.")
        when 49664 # "c200"
          # Failure: Unable to support requested template. Related fields: 0000,0901, 0000,0902
          logger.error("Failure! SCP has given the following reason: 'Unable to support requested template'.")
        when 65024 # "fe00"
          # Cancel: Matching terminated due to Cancel request.
          logger.info("Cancel! SCP has given the following reason: 'Matching terminated due to Cancel request'.")
        when 65280 # "ff00"
          # Sub-operations are continuing.
          # (No particular action taken, the program will listen for and receive the coming fragments)
        when 65281 # "ff01"
          # More command/data fragments to follow.
          # (No particular action taken, the program will listen for and receive the coming fragments)
        else
          logger.error("Something was NOT successful regarding the desired operation. SCP responded with error code: #{status} (tag: 0000,0900). See DICOM PS3.7, Annex C for details.")
      end
    end

    # Handles an incoming network transmission.
    # Returns the binary string data received.
    #
    # === Notes
    #
    # If a minimum length has been specified, and a message is received which is shorter than this length,
    # the method will keep listening for more incoming network packets to append.
    #
    # === Parameters
    #
    # * <tt>min_length</tt> -- Fixnum. The minimum possible length of a valid incoming transmission.
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
      data
    end

    # Receives the data from an incoming network transmission.
    # Returns the binary string data received.
    #
    def receive_transmission_data
      data = false
      response = IO.select([@session], nil, nil, @timeout)
      if response.nil?
        logger.error("No answer was received within the specified timeout period. Aborting.")
        stop_receiving
      else
        data = @session.recv(@max_receive_size)
      end
      data
    end

    # Sets some default values related to encoding.
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

    # Set instance variables related to a transfer syntax.
    #
    # === Parameters
    #
    # * <tt>syntax</tt> -- A transfer syntax string.
    #
    def set_transfer_syntax(syntax)
      @transfer_syntax = syntax
      # Query the library with our particular transfer syntax string:
      ts = LIBRARY.uid(@transfer_syntax)
      @explicit = ts ? ts.explicit? : true
      @data_endian = ts ? ts.big_endian? : false
      logger.warn("Invalid/unknown transfer syntax encountered: #{@transfer_syntax} Will try to continue, but errors may occur.") unless ts
    end

    # Sets the @user_information items instance array.
    #
    # === Notes
    #
    # Each user information item is a three element array consisting of: item type code, VR & value.
    #
    # === Parameters
    #
    # * <tt>info</tt> -- An association information hash.
    #
    def set_user_information_array(info=nil)
      @user_information = [
        [ITEM_MAX_LENGTH, "UL", @max_package_size],
        [ITEM_IMPLEMENTATION_UID, "STR", UID_ROOT],
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
            msg = Stream.new('', @net_endian)
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

    # Toggles two instance variables that in causes the loops that listen for incoming network packets to break.
    #
    # === Notes
    #
    # This method is called by the various methods that interpret incoming data when they have verified that
    # the entire message has been received, or when a timeout is reached.
    #
    def stop_receiving
      @listen = false
      @receive = false
    end

  end
end
