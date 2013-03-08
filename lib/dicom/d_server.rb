module DICOM

  # This class contains code for setting up a Service Class Provider (SCP),
  # which will act as a simple storage node (a DICOM server that receives images).
  #
  class DServer
    include Logging

    # Runs the server and takes a block for initializing.
    #
    # @param [Integer] port the network port to be used (defaults to 104)
    # @param [String] path the directory where incoming DICOM files will be stored (defaults to './received/')
    # @param [&block] block a block of code that will be run on the DServer instance, between creation and the launch of the SCP itself
    #
    # @example Run a server instance with a custom file handler
    #   require 'dicom'
    #   require 'my_file_handler'
    #   include DICOM
    #   DServer.run(104, 'c:/temp/') do |s|
    #     s.timeout = 100
    #     s.file_handler = MyFileHandler
    #   end
    #
    def self.run(port=104, path='./received/', &block)
      server = DServer.new(port)
      server.instance_eval(&block)
      server.start_scp(path)
    end

    # A customized FileHandler class to use instead of the default FileHandler included with ruby-dicom.
    attr_accessor :file_handler
    # The hostname that the TCPServer binds to.
    attr_accessor :host
    # The name of the server (application entity).
    attr_accessor :host_ae
    # The maximum allowed size of network packages (in bytes).
    attr_accessor :max_package_size
    # The network port to be used.
    attr_accessor :port
    # The maximum period the server will wait on an answer from a client before aborting the communication.
    attr_accessor :timeout

    # A hash containing the abstract syntaxes that will be accepted.
    attr_reader :accepted_abstract_syntaxes
    # A hash containing the transfer syntaxes that will be accepted.
    attr_reader :accepted_transfer_syntaxes

    # Creates a DServer instance.
    #
    # @note To customize logging behaviour, refer to the Logging module documentation.
    #
    # @param [Integer] port the network port to be used
    # @param [Hash] options the options to use for the DICOM server
    # @option options [String] :file_handler a customized FileHandler class to use instead of the default FileHandler
    # @option options [String] :host the hostname that the TCPServer binds to (defaults to '0.0.0.0')
    # @option options [String] :host_ae the name of the server (application entity)
    # @option options [String] :max_package_size the maximum allowed size of network packages (in bytes)
    # @option options [String] :timeout the number of seconds the server will wait on an answer from a client before aborting the communication
    #
    # @example Create a server using default settings
    #   s = DICOM::DServer.new
    # @example Create a server with a specific host name and a custom buildt file handler
    #   require_relative 'my_file_handler'
    #   server = DICOM::DServer.new(104, :host_ae => "RUBY_SERVER", :file_handler => DICOM::MyFileHandler)
    #
    def initialize(port=104, options={})
      require 'socket'
      # Required parameters:
      @port = port
      # Optional parameters (and default values):
      @file_handler = options[:file_handler] || FileHandler
      @host = options[:host] || '0.0.0.0'
      @host_ae =  options[:host_ae]  || "RUBY_DICOM"
      @max_package_size = options[:max_package_size] || 32768 # 16384
      @timeout = options[:timeout] || 10 # seconds
      @min_length = 12 # minimum number of bytes to expect in an incoming transmission
      # Variables used for monitoring state of transmission:
      @connection = nil # TCP connection status
      @association = nil # DICOM Association status
      @request_approved = nil # Status of our DICOM request
      @release = nil # Status of received, valid release response
      set_default_accepted_syntaxes
    end

    # Adds an abstract syntax to the list of abstract syntaxes that the server will accept.
    #
    # @param [String] uid an abstract syntax UID
    #
    def add_abstract_syntax(uid)
      lib_uid = LIBRARY.uid(uid)
      raise "Invalid/unknown UID: #{uid}" unless lib_uid
      @accepted_abstract_syntaxes[uid] = lib_uid.name
    end

    # Adds a transfer syntax to the list of transfer syntaxes that the server will accept.
    #
    # @param [String] uid a transfer syntax UID
    #
    def add_transfer_syntax(uid)
      lib_uid = LIBRARY.uid(uid)
      raise "Invalid/unknown UID: #{uid}" unless lib_uid
      @accepted_transfer_syntaxes[uid] = lib_uid.name
    end

    # Prints the list of accepted abstract syntaxes to the screen.
    #
    def print_abstract_syntaxes
      # Determine length of longest key to ensure pretty print:
      max_uid = @accepted_abstract_syntaxes.keys.collect{|k| k.length}.max
      puts "Abstract syntaxes which are accepted by this SCP:"
      @accepted_abstract_syntaxes.sort.each do |pair|
        puts "#{pair[0]}#{' '*(max_uid-pair[0].length)} #{pair[1]}"
      end
    end

    # Prints the list of accepted transfer syntaxes to the screen.
    #
    def print_transfer_syntaxes
      # Determine length of longest key to ensure pretty print:
      max_uid = @accepted_transfer_syntaxes.keys.collect{|k| k.length}.max
      puts "Transfer syntaxes which are accepted by this SCP:"
      @accepted_transfer_syntaxes.sort.each do |pair|
        puts "#{pair[0]}#{' '*(max_uid-pair[0].length)} #{pair[1]}"
      end
    end

    # Deletes a specific abstract syntax from the list of abstract syntaxes
    # that the server will accept.
    #
    # @param [String] uid an abstract syntax UID
    #
    def delete_abstract_syntax(uid)
      if uid.is_a?(String)
        @accepted_abstract_syntaxes.delete(uid)
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Deletes a specific transfer syntax from the list of transfer syntaxes
    # that the server will accept.
    #
    # @param [String] uid a transfer syntax UID
    #
    def delete_transfer_syntax(uid)
      if uid.is_a?(String)
        @accepted_transfer_syntaxes.delete(uid)
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Completely clears the list of abstract syntaxes that the server will accept.
    #
    # Following such a clearance, the user must ensure to add the specific
    # abstract syntaxes that are to be accepted by the server.
    #
    def clear_abstract_syntaxes
      @accepted_abstract_syntaxes = Hash.new
    end

    # Completely clears the list of transfer syntaxes that the server will accept.
    #
    # Following such a clearance, the user must ensure to add the specific
    # transfer syntaxes that are to be accepted by the server.
    #
    def clear_transfer_syntaxes
      @accepted_transfer_syntaxes = Hash.new
    end

    # Starts the Service Class Provider (SCP).
    #
    # This service acts as a simple storage node, which receives DICOM files
    # and stores them in the specified folder.
    #
    # Customized storage actions can be set my modifying or replacing the FileHandler class.
    #
    # @param [String] path the directory where incoming files are to be saved
    #
    def start_scp(path='./received/')
      if @accepted_abstract_syntaxes.size > 0 and @accepted_transfer_syntaxes.size > 0
        logger.info("Started DICOM SCP server on port #{@port}.")
        logger.info("Waiting for incoming transmissions...\n\n")
        # Initiate server:
        @scp = TCPServer.new(@host, @port)
        # Use a loop to listen for incoming messages:
        loop do
          Thread.start(@scp.accept) do |session|
            # Initialize the network package handler for this session:
            link = Link.new(:host_ae => @host_ae, :max_package_size => @max_package_size, :timeout => @timeout, :file_handler => @file_handler)
            link.set_session(session)
            # Note who has contacted us:
            logger.info("Connection established with:  #{session.peeraddr[2]}  (IP: #{session.peeraddr[3]})")
            # Receive an incoming message:
            segments = link.receive_multiple_transmissions
            info = segments.first
            # Interpret the received message:
            if info[:valid]
              association_error = check_association_request(info)
              unless association_error
                info, approved, rejected = process_syntax_requests(info)
                link.handle_association_accept(info)
                context = (LIBRARY.uid(info[:pc].first[:abstract_syntax]) ? LIBRARY.uid(info[:pc].first[:abstract_syntax]).name : 'Unknown UID!')
                if approved > 0
                  if approved == 1
                    logger.info("Accepted the association request with context: #{context}")
                  else
                    if rejected == 0
                      logger.info("Accepted all #{approved} proposed contexts in the association request.")
                    else
                      logger.warn("Accepted only #{approved} of #{approved+rejected} of the proposed contexts in the association request.")
                    end
                  end
                  # Process the incoming data. This method will also take care of releasing the association:
                  success, messages = link.handle_incoming_data(path)
                  # Pass along any messages that has been recorded:
                  messages.each { |m| logger.public_send(m.first, m.last) } if messages.first
                else
                  # No abstract syntaxes in the incoming request were accepted:
                  if rejected == 1
                    logger.warn("Rejected the association request with proposed context: #{context}")
                  else
                    logger.warn("Rejected all #{rejected} proposed contexts in the association request.")
                  end
                  # Since the requested abstract syntax was not accepted, the association must be released.
                  link.await_release
                end
              else
                # The incoming association was not formally correct.
                link.handle_rejection
              end
            else
              # The incoming message was not recognised as a valid DICOM message. Abort:
              link.handle_abort
            end
            # Terminate the connection:
            link.stop_session
            logger.info("Connection closed.\n\n")
          end
        end
      else
        raise "Unable to start SCP server as no accepted abstract syntaxes have been set!" if @accepted_abstract_syntaxes.length == 0
        raise "Unable to start SCP server as no accepted transfer syntaxes have been set!" if @accepted_transfer_syntaxes.length == 0
      end
    end


    private


    # Checks if the association request is formally correct, by matching against an exact application context UID.
    # Returns nil if valid, and an error code if it is not approved.
    #
    # === Notes
    #
    # Other things can potentially be checked here too, if we want to make the server more strict with regards to what information is received:
    # * Application context name, calling AE title, called AE title
    # * Description of error codes are given in the DICOM Standard, PS 3.8, Chapter 9.3.4 (Table 9-21).
    #
    # === Parameters
    #
    # * <tt>info</tt> -- An information hash from the received association request.
    #
    def check_association_request(info)
      unless info[:application_context] == APPLICATION_CONTEXT
        error = 2 # (application context name not supported)
        logger.error("The application context in the incoming association request was not recognized: (#{info[:application_context]})")
      else
        error = nil
      end
      return error
    end

    # Checks if the requested abstract syntax & its transfer syntax(es) are supported by this server instance,
    # and inserts a corresponding result code for each presentation context.
    # Returns the modified association information hash, as well as the number of abstract syntaxes that were accepted and rejected.
    #
    # === Notes
    #
    # * Description of error codes are given in the DICOM Standard, PS 3.8, Chapter 9.3.3.2 (Table 9-18).
    #
    # === Parameters
    #
    # * <tt>info</tt> -- An information hash from the received association request.
    #
    def process_syntax_requests(info)
      # A couple of variables used to analyse the properties of the association:
      approved = 0
      rejected = 0
      # Loop through the presentation contexts:
      info[:pc].each do |pc|
        if @accepted_abstract_syntaxes[pc[:abstract_syntax]]
          # Abstract syntax accepted. Proceed to check its transfer syntax(es):
          proposed_transfer_syntaxes = pc[:ts].collect{|t| t[:transfer_syntax]}.sort
          # Choose the first proposed transfer syntax that exists in our list of accepted transfer syntaxes:
          accepted_transfer_syntax = nil
          proposed_transfer_syntaxes.each do |proposed_ts|
            if @accepted_transfer_syntaxes.include?(proposed_ts)
              accepted_transfer_syntax = proposed_ts
              break
            end
          end
          if accepted_transfer_syntax
            # Both abstract and transfer syntax has been approved:
            pc[:result] = ACCEPTANCE
            pc[:selected_transfer_syntax] = accepted_transfer_syntax
            # Update our status variables:
            approved += 1
          else
            # No transfer syntax was accepted for this particular presentation context:
            pc[:result] = TRANSFER_SYNTAX_REJECTED
            rejected += 1
          end
        else
          # Abstract syntax rejected:
          pc[:result] = ABSTRACT_SYNTAX_REJECTED
        end
      end
      return info, approved, rejected
    end

    # Sets the default accepted abstract syntaxes and transfer syntaxes for this SCP.
    #
    def set_default_accepted_syntaxes
      @accepted_transfer_syntaxes, @accepted_abstract_syntaxes = LIBRARY.extract_transfer_syntaxes_and_sop_classes
    end

  end
end
