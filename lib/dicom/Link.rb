#    Copyright 2009-2010 Christoffer Lervag

module DICOM

  # This class handles the construction and interpretation of network packages
  # as well as network communication.
  class Link

    attr_accessor :max_package_size, :verbose, :file_handler
    attr_reader :errors, :notices

    # Initialize the instance with a host adress and a port number.
    def initialize(options={})
      require 'socket'
      # Optional parameters (and default values):
      @file_handler = options[:file_handler] || FileHandler
      @ae =  options[:ae]  || "RUBY_DICOM"
      @host_ae =  options[:host_ae]  || "DEFAULT"
      @max_package_size = options[:max_package_size] || 32768 # 16384
      @max_receive_size = @max_package_size
      @timeout = options[:timeout] || 10 # seconds
      @min_length = 12 # minimum number of bytes to expect in an incoming transmission
      @verbose = options[:verbose]
      @verbose = true if @verbose == nil # Default verbosity is 'on'.
      # Other instance variables:
      @errors = Array.new # errors and warnings are put in this array
      @notices = Array.new # information on successful transmissions are put in this array
      # Variables used for monitoring state of transmission:
      @connection = nil # TCP connection status
      @association = nil # DICOM Association status
      @request_approved = nil # Status of our DICOM request
      @release = nil # Status of received, valid release response
      set_default_values
      set_user_information_array
      @outgoing = Stream.new(nil, true, true)
    end


    # Build the abort message which is transmitted when the server wishes to (abruptly) abort the connection.
    # For the moment: NO REASONS WILL BE PROVIDED. (and source of problems will always be set as client side)
    def build_association_abort
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      pdu = "07"
      # Reserved (2 bytes)
      @outgoing.encode_last("00"*2, "HEX")
      # Source (1 byte)
      source = "00" # (client side error)
      @outgoing.encode_last(source, "HEX")
      # Reason/Diag. (1 byte)
      reason = "00" # (Reason not specified)
      @outgoing.encode_last(reason, "HEX")
      append_header(pdu)
    end


    # Build the binary string that will be sent as TCP data in the Association accept response.
    def build_association_accept(info, ac_uid, ui, result)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Set item types (pdu and presentation context):
      pdu = "02"
      pc_type = "21"
      # No abstract syntax in association response:
      abstract_syntax = nil
      # Note: The order of which these components are built is not arbitrary.
      append_application_context(ac_uid)
      # Return one presentation context for each of the proposed abstract syntaxes:
      abstract_syntaxes = Array.new
      info[:pc].each do |pc|
        unless abstract_syntaxes.include?(pc[:abstract_syntax])
          abstract_syntaxes << pc[:abstract_syntax]
          context_id = pc[:presentation_context_id]
          transfer_syntax = pc[:ts].first[:transfer_syntax]
          append_presentation_context(abstract_syntax, pc_type, transfer_syntax, context_id, result)
        end
      end
      append_user_information(ui)
      # Header must be built last, because we need to know the length of the other components.
      append_association_header(pdu)
    end


    # Build the binary string that will be sent as TCP data in the association rejection.
    # NB: For the moment, this method will only customize the "reason" value.
    # For a list of error codes, see the official dicom 08_08.pdf, page 41.
    def build_association_reject(info)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      pdu = "03"
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
      append_header(pdu)
    end


    # Build the binary string that will be sent as TCP data in the Association request.
    def build_association_request(ac_uid, as, ts, ui)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      # Set item types (pdu and presentation context):
      pdu = "01"
      pc = "20"
      # Note: The order of which these components are built is not arbitrary.
      # (The first three are built 'in order of appearance', the header is built last, but is put first in the message)
      append_application_context(ac_uid)
      append_presentation_context(as, pc, ts)
      append_user_information(ui)
      # Header must be built last, because we need to know the length of the other components.
      append_association_header(pdu)
    end


    # Build the binary string that will be sent as TCP data in the query command fragment.
    # Typical values:
    # pdu = "04" (data), context = "01", flags = "03"
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
      @outgoing.encode_first(context, "HEX") # Explicit VR Little Endian, Study Root Query/Retrieve.... (what does this reference, the earlier abstract syntax? transfer syntax?)
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(pdu)
    end


    # Build the binary string that will be sent as TCP data in the query data fragment.
    # The style of encoding will depend on whether we have an implicit or explicit transfer syntax.
    def build_data_fragment(data_elements)
      # Endianness of data fragment:
      @outgoing.set_endian(@data_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      pdu = "04"
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
      @outgoing.encode_first("01", "HEX") # Explicit VR Little Endian, Study Root Query/Retrieve.... (what does this reference, the earlier abstract syntax? transfer syntax?)
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(pdu)
    end


    # Build the binary string that will be sent as TCP data in the association release request:
    def build_release_request
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      pdu = "05"
      # Reserved (4 bytes)
      @outgoing.encode_last("00"*4, "HEX")
      append_header(pdu)
    end


    # Build the binary string that will be sent as TCP data in the association release response.
    def build_release_response
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Clear the outgoing binary string:
      @outgoing.reset
      pdu = "06"
      # Reserved (4 bytes)
      @outgoing.encode_last("00000000", "HEX")
      append_header(pdu)
    end


    # Build the binary string that makes up a storage data fragment.
    # Typical value: flags = "00" (more fragments following), flags = "02" (last fragment)
    # pdu = "04", context = "01"
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
      @outgoing.encode_first(context, "HEX")
      # PDV Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # PRESENTATION DATA VALUE (the above)
      append_header(pdu)
    end
    
    
    # Extracts the abstrax syntax from the first presentation context in the info hash object:
    def extract_abstract_syntax(info)
      return info[:pc].first[:abstract_syntax]
    end
    
    
    # Extracts the (first) transfer syntax from the first presentation context in the info hash object:
    def extract_transfer_syntax(info)
      return info[:pc].first[:ts].first[:transfer_syntax]
    end


    # Delegates an incoming message to its correct interpreter method, based on pdu type.
    def forward_to_interpret(message, pdu, file = nil)
      case pdu
        when "01" # Associatin request
          info = interpret_association_request(message)
        when "02" # Accepted association
          info = interpret_association_accept(message)
        when "03" # Rejected association
          info = interpret_association_reject(message)
        when "04" # Data
          info = interpret_command_and_data(message, file)
        when "05"
          info = interpret_release_request(message)
        when "06" # Release response
          info = interpret_release_response(message)
        when "07" # Abort connection
          info = interpret_abort(message)
        else
          info = {:valid => false}
          add_error("An unknown pdu type was received in the incoming transmission. Can not decode this message. (pdu: #{pdu})")
      end
      return info
    end


    # Handles the abortion of a session, when a non-valid message has been received.
    def handle_abort(session)
      add_notice("An unregonizable (non-DICOM) message was received.")
      build_association_abort
      transmit(session)
    end


    # Handles the association accept.
    def handle_association_accept(session, info, syntax_result)
      # Update the variable for calling ae (information gathered in the association request):
      @ae = info[:calling_ae]
      application_context = info[:application_context]
      set_user_information_array(info)
      build_association_accept(info, application_context, @user_information, syntax_result)
      transmit(session)
    end


    # Process the data that was received from the user.
    # We expect this to be an initial C-STORE-RQ followed by a bunch of data fragments.
    def handle_incoming_data(session, path)
      # Wait for incoming data:
      segments = receive_multiple_transmissions(session, file = true)
      # Reset command results arrays:
      @command_results = Array.new
      @data_results = Array.new
      # Try to extract data:
      file_data = Array.new
      segments.each do |info|
        if info[:valid]
          # Determine if it is command or data:
          if info[:presentation_context_flag] == "00" or info[:presentation_context_flag] == "02"
            # Data (last fragment)
            @data_results << info[:results]
            file_data  << info[:bin]
          elsif info[:presentation_context_flag] == "03"
            # Command (last fragment):
            @command_results << info[:results]
            @presentation_context_id = info[:presentation_context_id]
          end
        end
      end
      data = file_data.join
      if data.length > 8
        # Read the received data stream and load it as a DICOM object:
        obj = DObject.new(data, :bin => true, :syntax => @transfer_syntax)
        # The actual handling of the DICOM object and (processing, saving, database storage, retransmission, etc)
        # is handled by the external FileHandler class, in order to make it as easy as possible for users to write
        # their own customised solutions for handling the incoming DICOM files:
        success_message = @file_handler.receive_file(obj, path, @transfer_syntax)
      else
        # Valid DICOM data not received:
        success_message = false
      end
      return success_message
    end


    # Handles the rejection of an association, when the formalities of the association is not correct.
    def handle_rejection(session)
      add_notice("An incoming association request was rejected. Error code: #{association_error}")
      # Insert the error code in the info hash:
      info[:reason] = association_error
      # Send an association rejection:
      build_association_reject(info)
      transmit(session)
    end


    # Handles the release of an association.
    def handle_release(session)
      segments = receive_single_transmission(session)
      info = segments.first
      if info[:pdu] == "05"
        add_notice("Received a release request. Releasing association.")
        build_release_response
        transmit(session)
      end
    end


    # Handles the response (C-STORE-RSP) when a DICOM object has been (successfully) received.
    def handle_response(session)
      tags = @command_results.first
      # Need to construct the command elements array:
      command_elements = Array.new
      # SOP Class UID:
      command_elements << ["0000,0002", "UI", tags["0000,0002"]]
      # Command Field:
      command_elements << ["0000,0100", "US", 32769] # C-STORE-RSP
      # Message ID Being Responded To:
      command_elements << ["0000,0120", "US", tags["0000,0110"]] # (Message ID)
      # Data Set Type:
      command_elements << ["0000,0800", "US", 257]
      # Status:
      command_elements << ["0000,0900", "US", 0] # (Success)
      # Affected SOP Instance UID:
      command_elements << ["0000,1000", "UI", tags["0000,1000"]]
      pdu = "04"
      context = @presentation_context_id
      flag = "03" # (Command, last fragment)
      build_command_fragment(pdu, context, flag, command_elements)
      transmit(session)
    end


    # Decode an incoming transmission., decide its type, and forward its content to the various methods that process these.
    def interpret(message, file = nil)
      if @first_part
        message = @first_part + message
        @first_part = nil
      end
      segments = Array.new
      # If the message is at least 8 bytes we can start decoding it:
      if message.length > 8
        # Create a new Stream instance to handle this response.
        msg = Stream.new(message, @net_endian, @explicit)
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


    # Decode the binary string received when the provider wishes to abort the connection, for some reason.
    def interpret_abort(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian, @explicit)
      # Reserved (2 bytes)
      reserved_bytes = msg.skip(2)
      # Source (1 byte)
      info[:source] = msg.decode(1, "HEX")
      # Reason/Diag. (1 byte)
      info[:reason] = msg.decode(1, "HEX")
      # Analyse the results:
      if info[:source] == "00"
        add_error("Warning: Connection has been aborted by the service provider because of an error by the service user (client side).")
      elsif info[:source] == "02"
        add_error("Warning: Connection has been aborted by the service provider because of an error by the service provider (server side).")
      else
        add_error("Warning: Connection has been aborted by the service provider, with an unknown cause of the problems. (error code: #{info[:source]})")
      end
      if info[:source] != "00"
        # Display reason for error:
        case info[:reason]
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
            add_error("Reason specified for abort: Unknown reason (Error code: #{info[:reason]})")
        end
      end
      stop_receiving
      @abort = true
      info[:valid] = true
      return info
    end


    # Decode the binary string received in the association response, and interpret its content.
    def interpret_association_accept(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian, @explicit)
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
      # Item type (1 byte)
      info[:presentation_item_type] = msg.decode(1, "HEX")
      # Reserved (1 byte)
      msg.skip(1)
      # Presentation item length (2 bytes)
      info[:presentation_item_length] = msg.decode(2, "US")
      # Presentation context ID (1 byte)
      info[:presentation_context_id] = msg.decode(1, "HEX")
      # Reserved (1 byte)
      msg.skip(1)
      # Result (& Reason) (1 byte)
      info[:result] = msg.decode(1, "BY")
      # Analyse the results:
      unless info[:result] == 0
        case info[:result]
          when 1
            add_error("Warning: DICOM Request was rejected by the host, reason: 'User-rejection'")
          when 2
            add_error("Warning: DICOM Request was rejected by the host, reason: 'No reason (provider rejection)'")
          when 3
            add_error("Warning: DICOM Request was rejected by the host, reason: 'Abstract syntax not supported'")
          when 4
            add_error("Warning: DICOM Request was rejected by the host, reason: 'Transfer syntaxes not supported'")
          else
            add_error("Warning: DICOM Request was rejected by the host, reason: 'UNKNOWN (#{info[:result]})' (Illegal reason provided)")
        end
      end
      # Reserved (1 byte)
      msg.skip(1)
      # Transfer syntax sub-item:
      # Item type (1 byte)
      info[:transfer_syntax_item_type] = msg.decode(1, "HEX")
      # Reserved (1 byte)
      msg.skip(1)
      # Transfer syntax item length (2 bytes)
      info[:transfer_syntax_item_length] = msg.decode(2, "US")
      # Transfer syntax name (variable length)
      info[:transfer_syntax] = msg.decode(info[:transfer_syntax_item_length], "STR")
      # USER INFORMATION:
      # Item type (1 byte) ("50")
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
          when "51"
            info[:max_pdu_length] = msg.decode(item_length, "UL")
            @max_receive_size = info[:max_pdu_length]
          when "52"
            info[:implementation_class_uid] = msg.decode(item_length, "STR")
          when "55"
            info[:implementation_version] = msg.decode(item_length, "STR")
          else
            add_error("Unknown user info item type received. Please update source code or contact author. (item type: " + item_type + ")")
        end
      end
      stop_receiving
      info[:valid] = true
      # Update transfer syntax settings for this instance:
      set_transfer_syntax(info[:transfer_syntax])
      return info
    end # of interpret_association_accept


    # Decode the association reject message and extract the error reasons given.
    def interpret_association_reject(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian, @explicit)
      # Reserved (1 byte)
      msg.skip(1)
      # Result (1 byte)
      info[:result] = msg.decode(1, "BY") # 1 for permanent and 2 for transient rejection
      # Source (1 byte)
      info[:source] = msg.decode(1, "BY")
      # Reason (1 byte)
      info[:reason] = msg.decode(1, "BY")
      add_error("Warning: ASSOCIATE Request was rejected by the host. Error codes: Result: #{info[:result]}, Source: #{info[:source]}, Reason: #{info[:reason]} (See DICOM 08_08, page 41: Table 9-21 for details.)")
      stop_receiving
      info[:valid] = true
      return info
    end


    # Decode the binary string received in the association request, and interpret its content.
    def interpret_association_request(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian, @explicit)
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
      info[:application_item_type] = msg.decode(1, "HEX") # "10"
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
        if item_type == "20"
          pc = Hash.new
          pc[:presentation_item_type] = item_type
          # Reserved (1 byte)
          msg.skip(1)
          # Presentation context item length (2 bytes)
          pc[:presentation_item_length] = msg.decode(2, "US")
          # Presentation context id (1 byte)
          pc[:presentation_context_id] = msg.decode(1, "HEX")
          # Reserved (3 bytes)
          msg.skip(3)
          presentation_contexts << pc
          # A presentation context contains an abstract syntax and one or more transfer syntaxes.
          # ABSTRACT SYNTAX SUB-ITEM:
          # Abstract syntax item type (1 byte)
          pc[:abstract_syntax_item_type] = msg.decode(1, "HEX") # "30"
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
            if item_type == "40"
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
          when "51"
            info[:max_pdu_length] = msg.decode(item_length, "UL")
          when "52"
            info[:implementation_class_uid] = msg.decode(item_length, "STR")
          when "53"
            # Asynchronous operations window negotiation (PS 3.7: D.3.3.3) (2*2 bytes)
            info[:maxnum_operations_invoked] = msg.decode(2, "US")
            info[:maxnum_operations_performed] = msg.decode(2, "US")
          when "55"
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
    end # of interpret_association_request


    # Decode the received command/data binary string, and interpret its content.
    # Decoding of data fragment will depend on the explicitness of the transmission.
    def interpret_command_and_data(message, file = nil)
      info = Hash.new
      msg = Stream.new(message, @net_endian, @explicit)
      # Length (of remaining PDV data) (4 bytes)
      info[:presentation_data_value_length] = msg.decode(4, "UL")
      # Calculate the last index position of this message element:
      last_index = info[:presentation_data_value_length] + msg.index
      # Presentation context ID (1 byte)
      info[:presentation_context_id] = msg.decode(1, "HEX") # "01" expected
      # Flags (1 byte)
      info[:presentation_context_flag] = msg.decode(1, "HEX") # "03" for command (last fragment), "02" for data
      # Little endian encoding from now on:
      msg.set_endian(@data_endian)
      # We will put the results in a hash:
      results = Hash.new
      if info[:presentation_context_flag] == "03"
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
        # Check if the command fragment indicates that this was the last of the response fragments for this query:
        status = results["0000,0900"]
        if status
          if status == 0
            # Last fragment (Break the while loop that listens continuously for incoming packets):
            add_notice("Receipt for successful execution of the desired request has been received. Closing communication.")
            stop_receiving
          elsif status == 65281
            # Status = "01 ff": More command/data fragments to follow.
            # (No particular action taken, the program will listen for and receive the coming fragments)
          elsif status == 65280
            # Status = "00 ff": Sub-operations are continuing.
            # (No particular action taken, the program will listen for and receive the coming fragments)
          else
            add_error("Error! Something was NOT successful regarding the desired operation. (SCP responded with error code: #{status}) (tag: 0000,0900)")
          end
        end
      elsif info[:presentation_context_flag] == "00" or info[:presentation_context_flag] == "02"
        # DATA FRAGMENT:
        # If this is a file transmission, we will delay the decoding for later:
        if file
          # Just store the binary string:
          info[:bin] = msg.rest_string
          # Abort the listening if this is last data fragment:
          if info[:presentation_context_flag] == "02"
            stop_receiving
          end
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


    # Decode the binary string received in the release request, and interpret its content.
    def interpret_release_request(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian, @explicit)
      # Reserved (4 bytes)
      reserved_bytes = msg.decode(4, "HEX")
      stop_receiving
      info[:valid] = true
      return info
    end


    # Decode the binary string received in the release response, and interpret its content.
    def interpret_release_response(message)
      info = Hash.new
      msg = Stream.new(message, @net_endian, @explicit)
      # Reserved (4 bytes)
      reserved_bytes = msg.decode(4, "HEX")
      stop_receiving
      info[:valid] = true
      return info
    end


    # Handle multiple incoming transmissions and return the interpreted, received data.
    def receive_multiple_transmissions(session, file = nil)
      @listen = true
      segments = Array.new
      while @listen
        # Receive data and append the current data to our segments array, which will be returned.
        data = receive_transmission(session, @min_length)
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


    # Handle an expected single incoming transmission and return the interpreted, received data.
    def receive_single_transmission(session)
      min_length = 8
      data = receive_transmission(session, min_length)
      segments = interpret(data)
      segments << {:valid => false} unless segments.length > 0
      return segments
    end


    # Send the encoded binary string (package) to its destination.
    def transmit(session)
      session.send(@outgoing.string, 0)
    end


    # Following methods are private:
    private


    # Adds a warning or error message to the instance array holding messages,
    # and if verbose variable is true, prints the message as well.
    def add_error(error)
      puts error if @verbose
      @errors << error
    end


    # Adds a notice (information regarding progress or successful communications) to the instance array,
    # and if verbosity is set for these kinds of messages, prints it to the screen as well.
    def add_notice(notice)
      puts notice if @verbose
      @notices << notice
    end


    # Builds the application context that is part of the association request.
    def append_application_context(ac_uid)
      # Application context item type (1 byte)
      @outgoing.encode_last("10", "HEX")
      # Reserved (1 byte)
      @outgoing.encode_last("00", "HEX")
      # Application context item length (2 bytes)
      @outgoing.encode_last(ac_uid.length, "US")
      # Application context (variable length)
      @outgoing.encode_last(ac_uid, "STR")
    end


    # Build the binary string that makes up the header part (part of the association request).
    def append_association_header(pdu)
      # Big endian encoding:
      @outgoing.set_endian(@net_endian)
      # Header will be encoded in opposite order, where the elements are being put first in the outgoing binary string.
      # Build last part of header first. This is necessary to be able to assess the length value.
      # Reserved (32 bytes)
      @outgoing.encode_first("00"*32, "HEX")
      # Calling AE title (16 bytes)
      calling_ae = @outgoing.encode_string_with_trailing_spaces(@ae, 16)
      @outgoing.add_first(calling_ae) # (pre-encoded value)
      # Called AE title (16 bytes)
      called_ae = @outgoing.encode_string_with_trailing_spaces(@host_ae, 16)
      @outgoing.add_first(called_ae) # (pre-encoded value)
      # Reserved (2 bytes)
      @outgoing.encode_first("0000", "HEX")
      # Protocol version (2 bytes)
      @outgoing.encode_first("0001", "HEX")
      append_header(pdu)
    end


    # Adds the header bytes to the outgoing, binary string (this part has the same structure for all dicom network messages)
    # PDU: "01", "02", etc..
    def append_header(pdu)
      # Length (of remaining data) (4 bytes)
      @outgoing.encode_first(@outgoing.string.length, "UL")
      # Reserved (1 byte)
      @outgoing.encode_first("00", "HEX")
      # PDU type (1 byte)
      @outgoing.encode_first(pdu, "HEX")
    end


    # Build the binary string that makes up the presentation context part (part of the association request).
    # For a list of error codes, see the official dicom 08_08.pdf, page 39.
    def append_presentation_context(as, pc, ts, context_id = "01", result = "00")
      # PRESENTATION CONTEXT:
      # Presentation context item type (1 byte)
      @outgoing.encode_last(pc, "HEX") # "20" (request) & "21" (response)
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
      @outgoing.encode_last(context_id, "HEX")
      # Reserved (1 byte)
      @outgoing.encode_last("00", "HEX")
      # (1 byte) Reserved (for association request) & Result/reason (for association accept response)
      @outgoing.encode_last(result, "HEX")
      # Reserved (1 byte)
      @outgoing.encode_last("00", "HEX")
      ## ABSTRACT SYNTAX SUB-ITEM: (only for request, not response)
      if as
        # Abstract syntax item type (1 byte)
        @outgoing.encode_last("30", "HEX")
        # Reserved (1 byte)
        @outgoing.encode_last("00", "HEX")
        # Abstract syntax item length (2 bytes)
        @outgoing.encode_last(as.length, "US")
        # Abstract syntax (variable length)
        @outgoing.encode_last(as, "STR")
      end
      ## TRANSFER SYNTAX SUB-ITEM:
      ts = [ts] if ts.is_a?(String)
      ts.each do |t|
        # Transfer syntax item type (1 byte)
        @outgoing.encode_last("40", "HEX")
        # Reserved (1 byte)
        @outgoing.encode_last("00", "HEX")
        # Transfer syntax item length (2 bytes)
        @outgoing.encode_last(t.length, "US")
        # Transfer syntax (variable length)
        @outgoing.encode_last(t, "STR")
      end
      # Update transfer syntax settings for this instance:
      set_transfer_syntax(ts.first)
    end


    # Adds the binary string that makes up the user information (part of the association request).
    def append_user_information(ui)
      # USER INFORMATION:
      # User information item type (1 byte)
      @outgoing.encode_last("50", "HEX")
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


    # Handles an incoming transmission.
    # Optional: Specify a minimum length of the incoming transmission. (If a message is received
    # which is shorter than this limit, the method will keep listening for more incoming packets to append)
    def receive_transmission(session, min_length=0)
      data = receive_transmission_data(session)
      # Check the nature of the received data variable:
      if data
        # Sometimes the incoming transmission may be broken up into smaller pieces:
        # Unless a short answer is expected, we will continue to listen if the first answer was too short:
        unless min_length == 0
          if data.length <= min_length
            addition = receive_transmission_data(session)
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
    def receive_transmission_data(session)
      data = false
      t1 = Time.now.to_f
      @receive = true
      thr = Thread.new{ data = session.recv(@max_receive_size); @receive = false }
      while @receive
        if (Time.now.to_f - t1) > @timeout
          Thread.kill(thr)
          add_error("No answer was received within the specified timeout period. Aborting.")
          stop_receiving
        end
      end
      return data
    end


    # Some default values.
    def set_default_values
      # Default endianness for network transmissions is Big Endian:
      @net_endian = true
      # Default endianness of data is little endian:
      @data_endian = false
      # It may turn out to be unncessary to define the following values at this early stage.
      # Explicitness
      @explicit = true
      # Transfer syntax (Implicit, little endian):
      set_transfer_syntax("1.2.840.10008.1.2")
    end


    # Set instance variables related to the transfer syntax.
    def set_transfer_syntax(value)
      # Query the library with our particular transfer syntax string:
      result = LIBRARY.process_transfer_syntax(value)
      # Result is a 3-element array: [Validity of ts, explicitness, endianness]
      unless result[0]
        add_error("Warning: Invalid/unknown transfer syntax encountered! Will try to continue, but errors may occur.")
      end
      # Update encoding variables:
      @explicit = result[1]
      @data_endian = result[2]
      @transfer_syntax = value
    end


    # Set user information [item type code, vr/type, value]
    def set_user_information_array(info = nil)
      @user_information = [
        ["51", "UL", @max_package_size], # Max PDU Length
        ["52", "STR", UID],
        ["55", "STR", NAME]
      ]
      # A bit of a hack to include "asynchronous operations window negotiation", if this has been included in the association request:
      if info
        @user_information.insert(2, ["53", "HEX", "00010001"]) if info[:maxnum_operations_invoked]
      end
    end
    
    
    # Breaks the loops that listen for incoming packets by changing a couple of instance variables.
    # This method is called by the various methods that interpret incoming data when they have verified that
    # the entire message has been received, or when a timeout is reached.
    def stop_receiving
      @listen = false
      @receive = false
    end


  end # of class
end # of module