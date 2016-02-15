
module DICOM

  # This class contains code for handling the client side of DICOM TCP/IP network communication.
  #
  # For more information regarding queries, such as required/optional attributes
  # and value matching, refer to the DICOM standard, PS3.4, C 2.2.
  #
  class DClient
    include Logging

    # The name of this client (application entity).
    attr_accessor :ae
    # The name of the server (application entity).
    attr_accessor :host_ae
    # The IP adress of the server.
    attr_accessor :host_ip
    # The maximum allowed size of network packages (in bytes).
    attr_accessor :max_package_size
    # The network port to be used.
    attr_accessor :port
    # The maximum period the client will wait on an answer from a server before aborting the communication.
    attr_accessor :timeout
    # An array, where each index contains a hash with the data elements received in a command response (with tags as keys).
    attr_reader :command_results
    # An array, where each index contains a hash with the data elements received in a data response (with tags as keys).
    attr_reader :data_results

    # Creates a DClient instance.
    #
    # @note To customize logging behaviour, refer to the Logging module documentation.
    #
    # @param [String] host_ip the IP adress of the server which you are going to communicate with
    # @param [Integer] port the network port to be used
    # @param [Hash] options the options to use for the network communication
    # @option options [String] :ae the name of this client (application entity)
    # @option options [String] :host_ae the name of the server (application entity)
    # @option options [Integer] :max_package_size the maximum allowed size of network packages (in bytes)
    # @option options [Integer] :timeout the number of seconds the client will wait on an answer from a server before aborting (defaults to 10)
    #
    # @example Create a client instance using default settings
    #   node = DICOM::DClient.new("10.1.25.200", 104)
    #
    def initialize(host_ip, port, options={})
      require 'socket'
      # Required parameters:
      @host_ip = host_ip
      @port = port
      # Optional parameters (and default values):
      @ae =  options[:ae]  || "RUBY_DICOM"
      @host_ae =  options[:host_ae]  || "DEFAULT"
      @max_package_size = options[:max_package_size] || 32768 # 16384
      @timeout = options[:timeout] || 10 # seconds
      @min_length = 12 # minimum number of bytes to expect in an incoming transmission
      # Variables used for monitoring state of transmission:
      @association = nil # DICOM Association status
      @request_approved = nil # Status of our DICOM request
      @release = nil # Status of received, valid release response
      @data_elements = []
      # Results from a query:
      @command_results = Array.new
      @data_results = Array.new
      # Setup the user information used in the association request::
      set_user_information_array
      # Initialize the network package handler:
      @link = Link.new(:ae => @ae, :host_ae => @host_ae, :max_package_size => @max_package_size, :timeout => @timeout)
    end

    # Tests the connection to the server by performing a C-ECHO procedure.
    #
    def echo
      # Verification SOP Class:
      set_default_presentation_context(VERIFICATION_SOP)
      perform_echo
    end

    # Queries a service class provider for images (composite object instances) that match the specified criteria.
    #
    # === Instance level attributes for this query:
    #
    # * '0008,0018' (SOP Instance UID)
    # * '0020,0013' (Instance Number)
    #
    # In addition to the above listed attributes, a number of "optional" attributes
    # may be specified. For a general list of optional object instance level attributes,
    # please refer to the DICOM standard, PS3.4 C.6.1.1.5, Table C.6-4.
    #
    # @note Caution: Calling this method without parameters will instruct your PACS
    #   to return info on ALL images in the database!
    # @param [Hash] query_params the query parameters to use
    # @option query_params [String] 'GGGG,EEEE' a tag and value pair to be used in the query
    #
    # @example Find all images belonging to a given study and series
    #   node.find_images('0020,000D' => '1.2.840.1145.342', '0020,000E' => '1.3.6.1.4.1.2452.6.687844')
    #
    def find_images(query_params={})
      # Study Root Query/Retrieve Information Model - FIND:
      set_default_presentation_context("1.2.840.10008.5.1.4.1.2.2.1")
      # These query attributes will always be present in the dicom query:
      default_query_params = {
        "0008,0018" => "", # SOP Instance UID
        "0008,0052" => "IMAGE", # Query/Retrieve Level: "IMAGE"
        "0020,0013" => "" # Instance Number
      }
      # Raising an error if a non-tag query attribute is used:
      query_params.keys.each do |tag|
        raise ArgumentError, "The supplied tag (#{tag}) is not valid. It must be a string of the form 'GGGG,EEEE'." unless tag.is_a?(String) && tag.tag?
      end
      # Set up the query parameters and carry out the C-FIND:
      set_data_elements(default_query_params.merge(query_params))
      perform_find
      return @data_results
    end

    # Queries a service class provider for patients that match the specified criteria.
    #
    # === Instance level attributes for this query:
    #
    # * '0008,0052' (Query/Retrieve Level)
    # * '0010,0010' (Patient's Name)
    # * '0010,0020' (Patient ID)
    # * '0010,0030' (Patient's Birth Date)
    # * '0010,0040' (Patient's Sex)
    #
    # In addition to the above listed attributes, a number of "optional" attributes
    # may be specified. For a general list of optional object instance level attributes,
    # please refer to the DICOM standard, PS3.4 C.6.1.1.2, Table C.6-1.
    #
    # @note Caution: Calling this method without parameters will instruct your PACS
    #   to return info on ALL patients in the database!
    # @param [Hash] query_params the query parameters to use
    # @option query_params [String] 'GGGG,EEEE' a tag and value pair to be used in the query
    #
    # @example Find all patients matching the given name
    #   node.find_patients('0010,0010' => 'James*')
    #
    def find_patients(query_params={})
      # Patient Root Query/Retrieve Information Model - FIND:
      set_default_presentation_context("1.2.840.10008.5.1.4.1.2.1.1")
      # Every query attribute with a value != nil (required) will be sent in the dicom query.
      # The query parameters with nil-value (optional) are left out unless specified.
      default_query_params = {
        "0008,0052" => "PATIENT", # Query/Retrieve Level: "PATIENT"
        "0010,0010" => "", # Patient's Name
        "0010,0020" => "" # Patient's ID
      }
      # Raising an error if a non-tag query attribute is used:
      query_params.keys.each do |tag|
        raise ArgumentError, "The supplied tag (#{tag}) is not valid. It must be a string of the form 'GGGG,EEEE'." unless tag.is_a?(String) && tag.tag?
      end
      # Set up the query parameters and carry out the C-FIND:
      set_data_elements(default_query_params.merge(query_params))
      perform_find
      return @data_results
    end

    # Queries a service class provider for series that match the specified criteria.
    #
    # === Instance level attributes for this query:
    #
    # * '0008,0060' (Modality)
    # * '0020,000E' (Series Instance UID)
    # * '0020,0011' (Series Number)
    #
    # In addition to the above listed attributes, a number of "optional" attributes
    # may be specified. For a general list of optional object instance level attributes,
    # please refer to the DICOM standard, PS3.4 C.6.1.1.4, Table C.6-3.
    #
    # @note Caution: Calling this method without parameters will instruct your PACS
    #   to return info on ALL series in the database!
    # @param [Hash] query_params the query parameters to use
    # @option query_params [String] 'GGGG,EEEE' a tag and value pair to be used in the query
    #
    # @example Find all series belonging to the given study
    #   node.find_series('0020,000D' => '1.2.840.1145.342')
    #
    def find_series(query_params={})
      # Study Root Query/Retrieve Information Model - FIND:
      set_default_presentation_context("1.2.840.10008.5.1.4.1.2.2.1")
      # Every query attribute with a value != nil (required) will be sent in the dicom query.
      # The query parameters with nil-value (optional) are left out unless specified.
      default_query_params = {
        "0008,0052" => "SERIES", # Query/Retrieve Level: "SERIES"
        "0008,0060" => "", # Modality
        "0020,000E" => "", # Series Instance UID
        "0020,0011" => "" # Series Number
      }
      # Raising an error if a non-tag query attribute is used:
      query_params.keys.each do |tag|
        raise ArgumentError, "The supplied tag (#{tag}) is not valid. It must be a string of the form 'GGGG,EEEE'." unless tag.is_a?(String) && tag.tag?
      end
      # Set up the query parameters and carry out the C-FIND:
      set_data_elements(default_query_params.merge(query_params))
      perform_find
      return @data_results
    end

    # Queries a service class provider for studies that match the specified criteria.
    #
    # === Instance level attributes for this query:
    #
    # * '0008,0020' (Study Date)
    # * '0008,0030' (Study Time)
    # * '0008,0050' (Accession Number)
    # * '0010,0010' (Patient's Name)
    # * '0010,0020' (Patient ID)
    # * '0020,000D' (Study Instance UID)
    # * '0020,0010' (Study ID)
    #
    # In addition to the above listed attributes, a number of "optional" attributes
    # may be specified. For a general list of optional object instance level attributes,
    # please refer to the DICOM standard, PS3.4 C.6.2.1.2, Table C.6-5.
    #
    # @note Caution: Calling this method without parameters will instruct your PACS
    #   to return info on ALL studies in the database!
    # @param [Hash] query_params the query parameters to use
    # @option query_params [String] 'GGGG,EEEE' a tag and value pair to be used in the query
    #
    # @example Find all studies matching the given study date and patient's id
    #   node.find_studies('0008,0020' => '20090604-', '0010,0020' => '123456789')
    #
    def find_studies(query_params={})
      # Study Root Query/Retrieve Information Model - FIND:
      set_default_presentation_context("1.2.840.10008.5.1.4.1.2.2.1")
      # Every query attribute with a value != nil (required) will be sent in the dicom query.
      # The query parameters with nil-value (optional) are left out unless specified.
      default_query_params = {
        "0008,0020" => "",  # Study Date
        "0008,0030" => "",  # Study Time
        "0008,0050" => "",  # Accession Number
        "0008,0052" => "STUDY", # Query/Retrieve Level:  "STUDY"
        "0010,0010" => "",  # Patient's Name
        "0010,0020" => "",  # Patient ID
        "0020,000D" => "",  # Study Instance UID
        "0020,0010" => ""  # Study ID
      }
      # Raising an error if a non-tag query attribute is used:
      query_params.keys.each do |tag|
        raise ArgumentError, "The supplied tag (#{tag}) is not valid. It must be a string of the form 'GGGG,EEEE'." unless tag.is_a?(String) && tag.tag?
      end
      # Set up the query parameters and carry out the C-FIND:
      set_data_elements(default_query_params.merge(query_params))
      perform_find
      return @data_results
    end

    # Retrieves a DICOM file from a service class provider (SCP/PACS).
    #
    # === Instance level attributes for this procedure:
    #
    # * '0008,0018' (SOP Instance UID)
    # * '0008,0052' (Query/Retrieve Level)
    # * '0020,000D' (Study Instance UID)
    # * '0020,000E' (Series Instance UID)
    #
    # @note This method has never actually been tested, and as such,
    #   it is probably not working! Feedback is welcome.
    #
    # @param [String] path the directory where incoming files will be saved
    # @param [Hash] options the options to use for retrieving the DICOM object
    # @option options [String] 'GGGG,EEEE' a tag and value pair to be used for the procedure
    #
    # @example Retrieve a file as specified by its UIDs
    #   node.get_image('c:/dicom/', '0008,0018' => sop_uid, '0020,000D' => study_uid, '0020,000E' => series_uid)
    #
    def get_image(path, options={})
      # Study Root Query/Retrieve Information Model - GET:
      set_default_presentation_context("1.2.840.10008.5.1.4.1.2.2.3")
      # Transfer the current options to the data_elements hash:
      set_command_fragment_get
      # Prepare data elements for this operation:
      set_data_fragment_get_image
      set_data_options(options)
      perform_get(path)
    end

    # Moves a single image to a DICOM server.
    #
    # This DICOM node must be a third party (i.e. not the client instance you
    # are requesting the move with!).
    #
    # === Instance level attributes for this procedure:
    #
    # * '0008,0018' (SOP Instance UID)
    # * '0008,0052' (Query/Retrieve Level)
    # * '0020,000D' (Study Instance UID)
    # * '0020,000E' (Series Instance UID)
    #
    # @param [String] destination the AE title of the DICOM server which will receive the file
    # @param [Hash] options the options to use for moving the DICOM object
    # @option options [String] 'GGGG,EEEE' a tag and value pair to be used for the procedure
    #
    # @example Move an image from e.q. a PACS to another SCP on the network
    #   node.move_image('SOME_SERVER', '0008,0018' => sop_uid, '0020,000D' => study_uid, '0020,000E' => series_uid)
    #
    def move_image(destination, options={})
      # Study Root Query/Retrieve Information Model - MOVE:
      set_default_presentation_context("1.2.840.10008.5.1.4.1.2.2.2")
      # Transfer the current options to the data_elements hash:
      set_command_fragment_move(destination)
      # Prepare data elements for this operation:
      set_data_fragment_move_image
      set_data_options(options)
      perform_move
    end

    # Move an entire study to a DICOM server.
    #
    # This DICOM node must be a third party (i.e. not the client instance you
    # are requesting the move with!).
    #
    # === Instance level attributes for this procedure:
    #
    # * '0008,0052' (Query/Retrieve Level)
    # * '0010,0020' (Patient ID)
    # * '0020,000D' (Study Instance UID)
    #
    # @param [String] destination the AE title of the DICOM server which will receive the files
    # @param [Hash] options the options to use for moving the DICOM objects
    # @option options [String] 'GGGG,EEEE' a tag and value pair to be used for the procedure
    #
    # @example Move an entire study from e.q. a PACS to another SCP on the network
    #   node.move_study('SOME_SERVER', '0010,0020' => pat_id, '0020,000D' => study_uid)
    #
    def move_study(destination, options={})
      # Study Root Query/Retrieve Information Model - MOVE:
      set_default_presentation_context("1.2.840.10008.5.1.4.1.2.2.2")
      # Transfer the current options to the data_elements hash:
      set_command_fragment_move(destination)
      # Prepare data elements for this operation:
      set_data_fragment_move_study
      set_data_options(options)
      perform_move
    end

    # Sends one or more DICOM files to a service class provider (SCP/PACS).
    #
    # @param [Array<String, DObject>, String, DObject] files a single file path or an array of paths, alternatively a DObject or an array of DObject instances
    # @example Send a DICOM file to a storage server
    #   node.send('my_file.dcm')
    #
    def send(files)
      # Prepare the DICOM object(s):
      objects, success, message = load_files(files)
      if success
        # Open a DICOM link:
        establish_association
        if association_established?
          if request_approved?
            # Continue with our c-store operation, since our request was accepted.
            # Handle the transmission:
            perform_send(objects)
          end
        end
        # Close the DICOM link:
        establish_release
      else
        # Failed when loading the specified parameter as DICOM file(s). Will not transmit.
        logger.error(message)
      end
    end

    # Tests the connection to the server in a very simple way  by negotiating
    # an association and then releasing it.
    #
    def test
      logger.info("TESTING CONNECTION...")
      success = false
      # Verification SOP Class:
      set_default_presentation_context(VERIFICATION_SOP)
      # Open a DICOM link:
      establish_association
      if association_established?
        if request_approved?
          success = true
        end
        # Close the DICOM link:
        establish_release
      end
      if success
        logger.info("TEST SUCCSESFUL!")
      else
        logger.warn("TEST FAILED!")
      end
      return success
    end


    private


    # Returns an array of supported transfer syntaxes for the specified transfer syntax.
    # For compressed transfer syntaxes, we currently do not support reencoding these to other syntaxes.
    #
    def available_transfer_syntaxes(transfer_syntax)
      case transfer_syntax
      when IMPLICIT_LITTLE_ENDIAN
        return [IMPLICIT_LITTLE_ENDIAN, EXPLICIT_LITTLE_ENDIAN]
      when EXPLICIT_LITTLE_ENDIAN
        return [EXPLICIT_LITTLE_ENDIAN, IMPLICIT_LITTLE_ENDIAN]
      when EXPLICIT_BIG_ENDIAN
        return [EXPLICIT_BIG_ENDIAN, IMPLICIT_LITTLE_ENDIAN]
      else # Compression:
        return [transfer_syntax]
      end
    end

    # Opens a TCP session with the server, and handles the association request as well as the response.
    #
    def establish_association
      # Reset some variables:
      @association = false
      @request_approved = false
      # Initiate the association:
      @link.build_association_request(@presentation_contexts, @user_information)
      @link.start_session(@host_ip, @port)
      @link.transmit
      info = @link.receive_multiple_transmissions.first
      # Interpret the results:
      if info && info[:valid]
        if info[:pdu] == PDU_ASSOCIATION_ACCEPT
          # Values of importance are extracted and put into instance variables:
          @association = true
          @max_pdu_length = info[:max_pdu_length]
          logger.info("Association successfully negotiated with host #{@host_ae} (#{@host_ip}).")
          # Check if all our presentation contexts was accepted by the host:
          process_presentation_context_response(info[:pc])
        else
          logger.error("Association was denied from host #{@host_ae} (#{@host_ip})!")
        end
      end
    end

    # Handles the release request along with the response, as well as closing the TCP connection.
    #
    def establish_release
      @release = false
      if @abort
        @link.stop_session
        logger.info("Association has been closed. (#{@host_ae}, #{@host_ip})")
      else
        unless @link.session.closed?
          @link.build_release_request
          @link.transmit
          info = @link.receive_single_transmission.first
          @link.stop_session
          if info[:pdu] == PDU_RELEASE_RESPONSE
            logger.info("Association released properly from host #{@host_ae}.")
          else
            logger.error("Association released from host #{@host_ae}, but a release response was not registered.")
          end
        else
          logger.error("Connection was closed by the host (for some unknown reason) before the association could be released properly.")
        end
      end
      @abort = false
    end

    # Finds and retuns the abstract syntax that is associated with the specified context id.
    #
    def find_abstract_syntax(id)
      @presentation_contexts.each_pair do |abstract_syntax, context_ids|
        return abstract_syntax if context_ids[id]
      end
    end

    # Loads one or more DICOM files.
    # Returns an array of DObject instances, an array of unique abstract syntaxes found among the files, a status boolean and a message string.
    #
    # === Parameters
    #
    # * <tt>files_or_objects</tt> -- A single file path or an array of paths, or a DObject or an array of DObject instances.
    #
    def load_files(files_or_objects)
      files_or_objects = [files_or_objects] unless files_or_objects.is_a?(Array)
      status = true
      message = ""
      objects = Array.new
      abstracts = Array.new
      id = 1
      @presentation_contexts = Hash.new
      files_or_objects.each do |file_or_object|
        if file_or_object.is_a?(String)
          # Temporarily increase the log threshold to suppress messages from the DObject class:
          client_level = logger.level
          logger.level = Logger::FATAL
          dcm = DObject.read(file_or_object)
          # Reset the logg threshold:
          logger.level = client_level
          if dcm.read_success
            # Load the DICOM object:
            objects << dcm
          else
            status = false
            message = "Failed to read a DObject from this file: #{file_or_object}"
          end
        elsif file_or_object.is_a?(DObject)
          # Load the DICOM object and its abstract syntax:
          abstracts << file_or_object.value("0008,0016")
          objects << file_or_object
        else
          status = false
          message = "Array contains invalid object: #{file_or_object.class}."
        end
      end
      # Extract available transfer syntaxes for the various sop classes found amongst these objects
      syntaxes = Hash.new
      objects.each do |dcm|
        sop_class = dcm.value("0008,0016")
        if sop_class
          transfer_syntaxes = available_transfer_syntaxes(dcm.transfer_syntax)
          if syntaxes[sop_class]
            syntaxes[sop_class] << transfer_syntaxes
          else
            syntaxes[sop_class] = transfer_syntaxes
          end
        else
          status = false
          message = "Missing SOP Class UID. Unable to transmit DICOM object"
        end
        # Extract the unique variations of SOP Class and syntaxes and construct the presentation context hash:
        syntaxes.each_pair do |sop_class, ts|
          selected_transfer_syntaxes = ts.flatten.uniq
          @presentation_contexts[sop_class] = Hash.new
          selected_transfer_syntaxes.each do |syntax|
            @presentation_contexts[sop_class][id] = {:transfer_syntaxes => [syntax]}
            id += 2
          end
        end
      end
      return objects, status, message
    end

    # Handles the communication involved in a DICOM C-ECHO.
    # Build the necessary strings and send the command and data element that makes up the echo request.
    # Listens for and interpretes the incoming echo response.
    #
    def perform_echo
      # Open a DICOM link:
      establish_association
      if association_established?
        if request_approved?
          # Continue with our echo, since the request was accepted.
          # Set the query command elements array:
          set_command_fragment_echo
          @link.build_command_fragment(PDU_DATA, presentation_context_id, COMMAND_LAST_FRAGMENT, @command_elements)
          @link.transmit
          # Listen for incoming responses and interpret them individually, until we have received the last command fragment.
          segments = @link.receive_multiple_transmissions
          process_returned_data(segments)
          # Print stuff to screen?
        end
        # Close the DICOM link:
        establish_release
      end
    end

    # Handles the communication involved in a DICOM query (C-FIND).
    # Build the necessary strings and send the command and data element that makes up the query.
    # Listens for and interpretes the incoming query responses.
    #
    def perform_find
      # Open a DICOM link:
      establish_association
      if association_established?
        if request_approved?
          # Continue with our query, since the request was accepted.
          # Set the query command elements array:
          set_command_fragment_find
          @link.build_command_fragment(PDU_DATA, presentation_context_id, COMMAND_LAST_FRAGMENT, @command_elements)
          @link.transmit
          @link.build_data_fragment(@data_elements, presentation_context_id)
          @link.transmit
          # A query response will typically be sent in multiple, separate packets.
          # Listen for incoming responses and interpret them individually, until we have received the last command fragment.
          segments = @link.receive_multiple_transmissions
          process_returned_data(segments)
        end
        # Close the DICOM link:
        establish_release
      end
    end

    # Handles the communication involved in a DICOM C-GET.
    # Builds and sends command & data fragment, then receives the incoming file data.
    #
    #--
    # FIXME: This method has never actually been tested, since it is difficult to find a host that accepts a c-get-rq.
    #
    def perform_get(path)
      # Open a DICOM link:
      establish_association
      if association_established?
        if request_approved?
          # Continue with our operation, since the request was accepted.
          @link.build_command_fragment(PDU_DATA, presentation_context_id, COMMAND_LAST_FRAGMENT, @command_elements)
          @link.transmit
          @link.build_data_fragment(@data_elements, presentation_context_id)
          @link.transmit
          # Listen for incoming file data:
          success = @link.handle_incoming_data(path)
          if success
            # Send confirmation response:
            @link.handle_response
          end
        end
        # Close the DICOM link:
        establish_release
      end
    end

    # Handles the communication involved in DICOM C-MOVE.
    # Build the necessary strings and sends the command element that makes up the move request.
    # Listens for and interpretes the incoming move response.
    #
    def perform_move
      # Open a DICOM link:
      establish_association
      if association_established?
        if request_approved?
          # Continue with our operation, since the request was accepted.
          @link.build_command_fragment(PDU_DATA, presentation_context_id, COMMAND_LAST_FRAGMENT, @command_elements)
          @link.transmit
          @link.build_data_fragment(@data_elements, presentation_context_id)
          @link.transmit
          # Receive confirmation response:
          segments = @link.receive_multiple_transmissions
          process_returned_data(segments)
        end
        # Close the DICOM link:
        establish_release
      end
    end

    # Handles the communication involved in DICOM C-STORE.
    # For each file, builds and sends command fragment, then builds and sends the data fragments that
    # conveys the information from the selected DICOM file.
    #
    def perform_send(objects)
      objects.each_with_index do |dcm, index|
        # Gather necessary information from the object (SOP Class & Instance UID):
        sop_class = dcm.value("0008,0016")
        sop_instance = dcm.value("0008,0018")
        if sop_class and sop_instance
          # Only send the image if its sop_class has been accepted by the receiver:
          if @approved_syntaxes[sop_class]
            # Set the command array to be used:
            message_id = index + 1
            set_command_fragment_store(sop_class, sop_instance, message_id)
            # Find context id and transfer syntax:
            presentation_context_id = @approved_syntaxes[sop_class][0]
            selected_transfer_syntax = @approved_syntaxes[sop_class][1]
            # Encode our DICOM object to a binary string which is split up in pieces, sufficiently small to fit within the specified maximum pdu length:
            # Set the transfer syntax of the DICOM object equal to the one accepted by the SCP:
            dcm.transfer_syntax = selected_transfer_syntax
            # Remove the Meta group, since it doesn't belong in a DICOM file transfer:
            dcm.delete_group(META_GROUP)
            max_header_length = 14
            data_packages = dcm.encode_segments(@max_pdu_length - max_header_length, selected_transfer_syntax)
            @link.build_command_fragment(PDU_DATA, presentation_context_id, COMMAND_LAST_FRAGMENT, @command_elements)
            @link.transmit
            # Transmit all but the last data strings:
            last_data_package = data_packages.pop
            data_packages.each do |data_package|
              @link.build_storage_fragment(PDU_DATA, presentation_context_id, DATA_MORE_FRAGMENTS, data_package)
              @link.transmit
            end
            # Transmit the last data string:
            @link.build_storage_fragment(PDU_DATA, presentation_context_id, DATA_LAST_FRAGMENT, last_data_package)
            @link.transmit
            # Receive confirmation response:
            segments = @link.receive_single_transmission
            process_returned_data(segments)
          end
        else
          logger.error("Unable to extract SOP Class UID and/or SOP Instance UID for this DICOM object. File will not be sent to its destination.")
        end
      end
    end

    # Processes the presentation contexts that are received in the association response
    # to extract the transfer syntaxes which have been accepted for the various abstract syntaxes.
    #
    # === Parameters
    #
    # * <tt>presentation_contexts</tt> -- An array where each index contains a presentation context hash.
    #
    def process_presentation_context_response(presentation_contexts)
      # Storing approved syntaxes in an Hash with the syntax as key and the value being an array with presentation context ID and the transfer syntax chosen by the SCP.
      @approved_syntaxes = Hash.new
      rejected = Hash.new
      # Reset the presentation context instance variable:
      @link.presentation_contexts = Hash.new
      accepted_pc = 0
      presentation_contexts.each do |pc|
        # Determine what abstract syntax this particular presentation context's id corresponds to:
        id = pc[:presentation_context_id]
        raise "Error! Even presentation context ID received in the association response. This is not allowed according to the DICOM standard!" if id.even?
        abstract_syntax = find_abstract_syntax(id)
        if pc[:result] == 0
          accepted_pc += 1
          @approved_syntaxes[abstract_syntax] = [id, pc[:transfer_syntax]]
          @link.presentation_contexts[id] = pc[:transfer_syntax]
        else
          rejected[abstract_syntax] = [id, pc[:transfer_syntax]]
        end
      end
      if rejected.length == 0
        @request_approved = true
        if @approved_syntaxes.length == 1 and presentation_contexts.length == 1
          logger.info("The presentation context was accepted by host #{@host_ae}.")
        else
          logger.info("All #{presentation_contexts.length} presentation contexts were accepted by host #{@host_ae} (#{@host_ip}).")
        end
      else
        # We still consider the request 'approved' if at least one context were accepted:
        @request_approved = true if @approved_syntaxes.length > 0
        logger.error("One or more of your presentation contexts were denied by host #{@host_ae}!")
        @approved_syntaxes.each_pair do |key, value|
          sntx_k = (LIBRARY.uid(key) ? LIBRARY.uid(key).name : 'Unknown UID!')
          sntx_v = (LIBRARY.uid(value[1]) ? LIBRARY.uid(value[1]).name : 'Unknown UID!')
          logger.info("APPROVED: #{sntx_k} (#{sntx_v})")
        end
        rejected.each_pair do |key, value|
          sntx_k = (LIBRARY.uid(key) ? LIBRARY.uid(key).name : 'Unknown UID!')
          sntx_v = (LIBRARY.uid(value[1]) ? LIBRARY.uid(value[1]).name : 'Unknown UID!')
          logger.error("REJECTED: #{sntx_k} (#{sntx_v})")
        end
      end
    end

    # Processes the array of information hashes that was returned from the interaction with the SCP
    # and transfers it to the instance variables where command and data results are stored.
    #
    def process_returned_data(segments)
      # Reset command results arrays:
      @command_results = Array.new
      @data_results = Array.new
      # Try to extract data:
      segments.each do |info|
        if info[:valid]
          # Determine if it is command or data:
          if info[:presentation_context_flag] == COMMAND_LAST_FRAGMENT
            @command_results << info[:results]
          elsif info[:presentation_context_flag] == DATA_LAST_FRAGMENT
            @data_results << info[:results]
          end
        end
      end
    end

    # Sets the command elements used in a C-ECHO-RQ.
    #
    def set_command_fragment_echo
      @command_elements = [
        ["0000,0002", "UI", @presentation_contexts.keys.first], # Affected SOP Class UID
        ["0000,0100", "US", C_ECHO_RQ],
        ["0000,0110", "US", DEFAULT_MESSAGE_ID],
        ["0000,0800", "US", NO_DATA_SET_PRESENT]
      ]
    end

    # Sets the command elements used in a C-FIND-RQ.
    #
    # === Notes
    #
    # * This setup is used for all types of queries.
    #
    def set_command_fragment_find
      @command_elements = [
        ["0000,0002", "UI", @presentation_contexts.keys.first], # Affected SOP Class UID
        ["0000,0100", "US", C_FIND_RQ],
        ["0000,0110", "US", DEFAULT_MESSAGE_ID],
        ["0000,0700", "US", 0], # Priority: 0: medium
        ["0000,0800", "US", DATA_SET_PRESENT]
      ]
    end

    # Sets the command elements used in a C-GET-RQ.
    #
    def set_command_fragment_get
      @command_elements = [
        ["0000,0002", "UI", @presentation_contexts.keys.first], # Affected SOP Class UID
        ["0000,0100", "US", C_GET_RQ],
        ["0000,0600", "AE", @ae], # Destination is ourselves
        ["0000,0700", "US", 0], # Priority: 0: medium
        ["0000,0800", "US", DATA_SET_PRESENT]
      ]
    end

    # Sets the command elements used in a C-MOVE-RQ.
    #
    def set_command_fragment_move(destination)
      @command_elements = [
        ["0000,0002", "UI", @presentation_contexts.keys.first], # Affected SOP Class UID
        ["0000,0100", "US", C_MOVE_RQ],
        ["0000,0110", "US", DEFAULT_MESSAGE_ID],
        ["0000,0600", "AE", destination],
        ["0000,0700", "US", 0], # Priority: 0: medium
        ["0000,0800", "US", DATA_SET_PRESENT]
      ]
    end

    # Sets the command elements used in a C-STORE-RQ.
    #
    def set_command_fragment_store(modality, instance, message_id)
      @command_elements = [
        ["0000,0002", "UI", modality], # Affected SOP Class UID
        ["0000,0100", "US", C_STORE_RQ],
        ["0000,0110", "US", message_id],
        ["0000,0700", "US", 0], # Priority: 0: medium
        ["0000,0800", "US", DATA_SET_PRESENT],
        ["0000,1000", "UI", instance] # Affected SOP Instance UID
      ]
    end

    # Sets the data elements used for an image C-GET-RQ.
    #
    def set_data_fragment_get_image
      @data_elements = [
        ["0008,0018", ""], # SOP Instance UID
        ["0008,0052", "IMAGE"], # Query/Retrieve Level:  "IMAGE"
        ["0020,000D", ""], # Study Instance UID
        ["0020,000E", ""] # Series Instance UID
      ]
    end

    # Sets the data elements used for an image C-MOVE-RQ.
    #
    def set_data_fragment_move_image
      @data_elements = [
        ["0008,0018", ""], # SOP Instance UID
        ["0008,0052", "IMAGE"], # Query/Retrieve Level:  "IMAGE"
        ["0020,000D", ""], # Study Instance UID
        ["0020,000E", ""] # Series Instance UID
      ]
    end

    # Sets the data elements used in a study C-MOVE-RQ.
    #
    def set_data_fragment_move_study
      @data_elements = [
        ["0008,0052", "STUDY"], # Query/Retrieve Level:  "STUDY"
        ["0010,0020", ""], # Patient ID
        ["0020,000D", ""] # Study Instance UID
      ]
    end

    # Transfers the user-specified options to the @data_elements instance array.
    #
    # === Restrictions
    #
    # * Only tag & value pairs for tags which are predefined for the specific request type will be stored!
    #
    def set_data_options(options)
      options.each_pair do |key, value|
        tags = @data_elements.transpose[0]
        i = tags.index(key)
        if i
          @data_elements[i][1] = value
        end
      end
    end

    # Creates the presentation context used for the non-file-transmission association requests..
    #
    def set_default_presentation_context(abstract_syntax)
      raise ArgumentError, "Expected String, got #{abstract_syntax.class}" unless abstract_syntax.is_a?(String)
      id = 1
      transfer_syntaxes = [IMPLICIT_LITTLE_ENDIAN, EXPLICIT_LITTLE_ENDIAN, EXPLICIT_BIG_ENDIAN]
      item = {:transfer_syntaxes => transfer_syntaxes}
      pc = {id => item}
      @presentation_contexts = {abstract_syntax => pc}
    end

    # Sets the @user_information items instance array.
    #
    # === Notes
    #
    # Each user information item is a three element array consisting of: item type code, VR & value.
    #
    def set_user_information_array
      @user_information = [
        [ITEM_MAX_LENGTH, "UL", @max_package_size],
        [ITEM_IMPLEMENTATION_UID, "STR", UID_ROOT],
        [ITEM_IMPLEMENTATION_VERSION, "STR", NAME]
      ]
    end

    # Checks if an association has been established.
    #
    def association_established?
      @association == true
    end

    # Checks if a request has been approved.
    #
    def request_approved?
      @request_approved == true
    end

    # Extracts the presentation context id from the approved syntax.
    #
    def presentation_context_id
      @approved_syntaxes.to_a.first[1][0] # ID of first (and only) syntax in this Hash.
    end

    # Sets the data_elements instance array with the given options.
    #
    def set_data_elements(options)
      @data_elements = []
      options.keys.sort.each do |tag|
        @data_elements << [ tag, options[tag] ] unless options[tag].nil?
      end
    end

  end
end
