module DICOM

  # This class contains code for setting up a Service Class Provider (SCP),
  # which will act as a simple storage node (a DICOM server that receives images).
  #
  class DServer

    # Runs the server and takes a block for initializing.
    #
    # === Parameters
    #
    # * <tt>port</tt> -- Fixnum. The network port to be used. Defaults to 104.
    # * <tt>path</tt> -- String. The path where incoming DICOM files will be stored. Defaults to "./received/".
    # * <tt>&block</tt> -- A block of code that will be run on the DServer instance, between creation and the launch of the SCP itself.
    #
    # === Examples
    #
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

    # A customized FileHandler class to use instead of the default FileHandler included with Ruby DICOM.
    attr_accessor :file_handler
    # The name of the server (application entity).
    attr_accessor :host_ae
    # The maximum allowed size of network packages (in bytes).
    attr_accessor :max_package_size
    # The network port to be used.
    attr_accessor :port
    # The maximum period the server will wait on an answer from a client before aborting the communication.
    attr_accessor :timeout
    # A boolean which defines if notices/warnings/errors will be printed to the screen (true) or not (false).
    attr_accessor :verbose

    # A hash containing the abstract syntaxes that will be accepted.
    attr_reader :accepted_abstract_syntaxes
    # A hash containing the transfer syntaxes that will be accepted.
    attr_reader :accepted_transfer_syntaxes
    # An array containing any error messages recorded.
    attr_reader :errors
    # An array containing any status messages recorded.
    attr_reader :notices

    # Creates a DServer instance.
    #
    # === Parameters
    #
    # * <tt>port</tt> -- Fixnum. The network port to be used. Defaults to 104.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:file_handler</tt> -- A customized FileHandler class to use instead of the default FileHandler.
    # * <tt>:host_ae</tt> -- String. The name of the server (application entity).
    # * <tt>:max_package_size</tt> -- Fixnum. The maximum allowed size of network packages (in bytes).
    # * <tt>:timeout</tt> -- Fixnum. The maximum period the server will wait on an answer from a client before aborting the communication.
    # * <tt>:verbose</tt> -- Boolean. If set to false, the DServer instance will run silently and not output warnings and error messages to the screen. Defaults to true.
    #
    # === Examples
    #
    #   # Create a server using default settings:
    #   s = DICOM::DServer.new
    #   # Create a server and specify a host name as well as a custom buildt file handler:
    #   require 'MyFileHandler'
    #   server = DICOM::DServer.new(104, :host_ae => "RUBY_SERVER", :file_handler => DICOM::MyFileHandler)
    #
    def initialize(port=104, options={})
      require 'socket'
      # Required parameters:
      @port = port
      # Optional parameters (and default values):
      @file_handler = options[:file_handler] || FileHandler
      @host_ae =  options[:host_ae]  || "RUBY_DICOM"
      @max_package_size = options[:max_package_size] || 32768 # 16384
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
      set_default_accepted_syntaxes
    end

    # Adds an abstract syntax to the list of abstract syntaxes that the server will accept.
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- An abstract syntax UID string.
    #
    def add_abstract_syntax(uid)
      if uid.is_a?(String)
        name = LIBRARY.get_syntax_description(uid) || "Unknown UID"
        @accepted_abstract_syntaxes[uid] = name
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Adds a transfer syntax to the list of transfer syntaxes that the server will accept.
    #
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- A transfer syntax UID string.
    #
    def add_transfer_syntax(uid)
      if uid.is_a?(String)
        name = LIBRARY.get_syntax_description(uid) || "Unknown UID"
        @accepted_transfer_syntaxes[uid] = name
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
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

    # Removes a specific abstract syntax from the list of abstract syntaxes that the server will accept.
    #
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- An abstract syntax UID string.
    #
    def remove_abstract_syntax(uid)
      if uid.is_a?(String)
        @accepted_abstract_syntaxes.delete(uid)
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Removes a specific transfer syntax from the list of transfer syntaxes that the server will accept.
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- A transfer syntax UID string.
    #
    def remove_transfer_syntax(uid)
      if uid.is_a?(String)
        @accepted_transfer_syntaxes.delete(uid)
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Completely clears the list of abstract syntaxes that the server will accept.
    #
    # === Notes
    #
    # * Following such a removal, the user must ensure to add the specific abstract syntaxes that are to be accepted by the server.
    #
    def remove_all_abstract_syntaxes
      @accepted_abstract_syntaxes = Hash.new
    end

    # Completely clears the list of transfer syntaxes that the server will accept.
    #
    # === Notes
    #
    # * Following such a removal, the user must ensure to add the specific transfer syntaxes that are to be accepted by the server.
    #
    def remove_all_transfer_syntaxes
      @accepted_transfer_syntaxes = Hash.new
    end

    # Starts the Service Class Provider (SCP).
    #
    # === Notes
    #
    # * This service acts as a simple storage node, which receives DICOM files and stores them in a specified folder.
    # * Customized storage actions can be set my modifying or replacing the FileHandler class.
    #
    # === Parameters
    #
    # * <tt>path</tt> -- The path where incoming files are to be saved.
    #
    def start_scp(path='./received/')
      if @accepted_abstract_syntaxes.size > 0 and @accepted_transfer_syntaxes.size > 0
        add_notice("Starting DICOM SCP server...")
        add_notice("*********************************")
        # Initiate server:
        @scp = TCPServer.new(@port)
        # Use a loop to listen for incoming messages:
        loop do
          Thread.start(@scp.accept) do |session|
            # Initialize the network package handler for this session:
            link = Link.new(:host_ae => @host_ae, :max_package_size => @max_package_size, :timeout => @timeout, :verbose => @verbose, :file_handler => @file_handler)
            link.set_session(session)
            # Note the time of reception as well as who has contacted us:
            add_notice(Time.now.strftime("%Y-%m-%d  %H:%M:%S"))
            add_notice("Connection established with:  #{session.peeraddr[2]}  (IP: #{session.peeraddr[3]})")
            # Receive an incoming message:
            segments = link.receive_multiple_transmissions
            info = segments.first
            # Interpret the received message:
            if info[:valid]
              association_error = check_association_request(info)
              unless association_error
                info, approved, rejected = process_syntax_requests(info)
                link.handle_association_accept(info)
                if approved > 0
                  if approved == 1
                    add_notice("Accepted the association request with context: #{LIBRARY.get_syntax_description(info[:pc].first[:abstract_syntax])}")
                  else
                    if rejected == 0
                      add_notice("Accepted all #{approved} proposed contexts in the association request.")
                    else
                      add_notice("Accepted only #{approved} of #{approved+rejected} of the proposed contexts in the association request.")
                    end
                  end
                  # Process the incoming data. This method will also take care of releasing the association:
                  success, messages = link.handle_incoming_data(path)
                  if success
                    add_notice(messages) if messages.first
                  else
                    # Something has gone wrong:
                    add_error(messages) if messages.first
                  end
                else
                  # No abstract syntaxes in the incoming request were accepted:
                  if rejected == 1
                    add_notice("Rejected the association request with proposed context: #{LIBRARY.get_syntax_description(info[:pc].first[:abstract_syntax])}")
                  else
                    add_notice("Rejected all #{rejected} proposed contexts in the association request.")
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
            add_notice("*********************************")
          end
        end
      else
        raise "Unable to start SCP server as no accepted abstract syntaxes have been set!" if @accepted_abstract_syntaxes.length == 0
        raise "Unable to start SCP server as no accepted transfer syntaxes have been set!" if @accepted_transfer_syntaxes.length == 0
      end
    end


    # Following methods are private:
    private


    # Adds a warning or error message to the instance array holding messages,
    # and prints the information to the screen if verbose is set.
    #
    # === Parameters
    #
    # * <tt>error</tt> -- A single error message or an array of error messages.
    #
    def add_error(error)
      if @verbose
        puts error
      end
      @errors << error
    end

    # Adds a notice (information regarding progress or successful communications) to the instance array,
    # and prints the information to the screen if verbose is set.
    #
    # === Parameters
    #
    # * <tt>notice</tt> -- A single status message or an array of status messages.
    #
    def add_notice(notice)
      if @verbose
        puts notice
      end
      @notices << notice
    end

    # Checks if the association request is formally correct, by matching against an exact application context UID.
    # Returns nil if valid, and an error code if it is not approved.
    #
    # === Notes
    #
    # Other things can potentionally be checked here too, if we want to make the server more strict with regards to what information is received:
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
        add_error("Error: The application context in the incoming association request was not recognized: (#{info[:application_context]})")
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