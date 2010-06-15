#    Copyright 2009-2010 Christoffer Lervag

module DICOM

  # This class contains code for setting up a Service Class Provider (SCP),
  # which will act as a simple storage node (a server that receives images).
  #
  class DServer

    # Run the server and take a block for initializing.
    #
    def self.run(port=104, path='./received/', &block)
      server = DServer.new(port)
      server.instance_eval(&block)
      server.start_scp(path)
    end

    # Accessible attributes:
    attr_accessor :host_ae, :max_package_size, :port, :timeout, :verbose, :file_handler
    attr_reader :accepted_abstract_syntaxes, :accepted_transfer_syntaxes, :errors, :notices

    # Initialize the instance with a host adress and a port number.
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

    # Adds a specified abstract syntax to the list of abstract syntaxes that the server instance will accept.
    #
    def add_abstract_syntax(uid)
      if uid.is_a?(String)
        name = LIBRARY.get_syntax_description(uid) || "Unknown UID" 
        @accepted_abstract_syntaxes[uid] = name
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Adds a specified abstract syntax to the list of transfer syntaxes that the server instance will accept.
    #
    def add_transfer_syntax(uid)
      if uid.is_a?(String)
        name = LIBRARY.get_syntax_description(uid) || "Unknown UID" 
        @accepted_transfer_syntaxes[uid] = name
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Print the list of valid abstract syntaxes to the screen.
    #
    def print_abstract_syntaxes
      # Determine length of longest key to ensure pretty print:
      max_uid = @accepted_abstract_syntaxes.keys.collect{|k| k.length}.max
      puts "Abstract syntaxes which are accepted by this SCP:"
      @accepted_abstract_syntaxes.sort.each do |pair|
        puts "#{pair[0]}#{' '*(max_uid-pair[0].length)} #{pair[1]}"
      end
    end

    # Print the list of valid transfer syntaxes to the screen.
    #
    def print_transfer_syntaxes
      # Determine length of longest key to ensure pretty print:
      max_uid = @accepted_transfer_syntaxes.keys.collect{|k| k.length}.max
      puts "Transfer syntaxes which are accepted by this SCP:"
      @accepted_transfer_syntaxes.sort.each do |pair|
        puts "#{pair[0]}#{' '*(max_uid-pair[0].length)} #{pair[1]}"
      end
    end

    # Remove a specific abstract syntax from the list of abstract syntaxes that the server instance will accept.
    #
    def remove_abstract_syntax(uid)
      if uid.is_a?(String)
        @accepted_abstract_syntaxes.delete(uid)
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Remove a specific transfer syntax from the list of transfer syntaxes that the server instance will accept.
    #
    def remove_transfer_syntax(uid)
      if uid.is_a?(String)
        @accepted_transfer_syntaxes.delete(uid)
      else
        raise "Invalid type of UID. Expected String, got #{uid.class}!"
      end
    end

    # Completely clear the list of abstract syntaxes that the server instance will accept.
    # Following such a removal, the user must ensure to add the specific abstract syntaxes that are to be accepted by the server instance.
    #
    def remove_all_abstract_syntaxes
      @accepted_abstract_syntaxes = Hash.new
    end

    # Completely clear the list of transfer syntaxes that the server instance will accept.
    # Following such a removal, the user must ensure to add the specific transfer syntaxes that are to be accepted by the server instance.
    #
    def remove_all_transfer_syntaxes
      @accepted_transfer_syntaxes = Hash.new
    end

    # Starts a Service Class Provider (SCP).
    # This service acts as a simple storage node, which receives DICOM files and stores them in a specified folder.
    # Customized storage actions can be set my modifying or replacing the FileHandler.
    #
    def start_scp(path='./received/')
      if @accepted_abstract_syntaxes.size > 0 and @accepted_transfer_syntaxes.size > 0
        add_notice("Starting SCP server...")
        add_notice("*********************************")
        # Initiate server:
        @scp = TCPServer.new(@port)
        # Use a loop to listen for incoming messages:
        loop do
          Thread.start(@scp.accept) do |session|
            # Initialize the network package handler for this session:
            link = Link.new(:host_ae => @host_ae, :max_package_size => @max_package_size, :timeout => @timeout, :verbose => @verbose, :file_handler => @file_handler)
            add_notice("Connection established (name: #{session.peeraddr[2]}, ip: #{session.peeraddr[3]})")
            # Receive an incoming message:
            #segments = link.receive_single_transmission(session)
            segments = link.receive_multiple_transmissions(session)
            info = segments.first
            # Interpret the received message:
            if info[:valid]
              association_error = check_association_request(info)
              unless association_error
                info, some_approved, test_only = process_syntax_requests(link, info)
                link.handle_association_accept(session, info)
                if some_approved
                  add_notice("An incoming association request has been accepted.")
                  if test_only
                    # Verification SOP Class (used for testing connections):
                    link.handle_release(session)
                  else
                    # Process the incoming data:
                    success, message = link.handle_incoming_data(session, path)
                    if success
                      add_notice(message)
                      # Send a receipt for received data:
                      link.handle_response(session)
                    else
                      # Something has gone wrong:
                      add_error(message)
                    end
                    # Release the connection:
                    link.handle_release(session)
                  end
                else
                  # No abstract syntaxes in the incoming request were accepted:
                  add_notice("An association was negotiated, but none of its presentation contexts were accepted. (#{abstract_syntax})")
                  # Since the requested abstract syntax was not accepted, the association must be released.
                  link.handle_release(session)
                end
              else
                # The incoming association was not formally correct.
                link.handle_rejection(session)
              end
            else
              # The incoming message was not recognised as a valid DICOM message. Abort:
              link.handle_abort(session)
            end
            # Terminate the connection:
            session.close unless session.closed?
            add_notice("Connection closed.")
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


    # Adds a warning or error message to the instance array holding messages, and if verbose variable is true, prints the message as well.
    #
    def add_error(error)
      if @verbose
        puts error
      end
      @errors << error
    end

    # Adds a notice (information regarding progress or successful communications) to the instance array,
    # and if verbosity is set for these kinds of messages, prints it to the screen as well.
    #
    def add_notice(notice)
      if @verbose
        puts notice
      end
      @notices << notice
    end

    # Check if the association request is formally correct.
    # Things that can be checked here, are:
    # Application context name, calling AE title, called AE title
    # Description of error codes are given in the DICOM Standard, PS 3.8, Chapter 9.3.4 (Table 9-21).
    #
    def check_association_request(info)
      # For the moment there is no control on AE titles, but this could easily be implemented if desired.
      # We check that the application context UID is as expected:
      unless info[:application_context] == APPLICATION_CONTEXT
        error = 2 # application context name not supported
        add_error("Error: The application context in the incoming association request was not recognized: (#{info[:application_context]})")
      else
        error = nil
      end
      return error
    end

    # Checks if the requested abstract syntax & it's transfer syntax(es) are supported by this instance,
    # and insert a proper result code for each presentation context.
    # Description of error codes are given in the DICOM Standard, PS 3.8, Chapter 9.3.3.2 (Table 9-18).
    # The method also checks to see if all presentation contexts were rejected, and whether or not the
    # presentation context indicates that only a connection test is beging performed.
    #
    def process_syntax_requests(link, info)
      # A couple of variables used to analyse the properties of the association:
      some_approved = false
      test_only = true
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
            some_approved = true
            test_only = false unless pc[:abstract_syntax] == VERIFICATION_SOP
          else
            # No transfer syntax was accepted for this particular presentation context:
            pc[:result] = TRANSFER_SYNTAX_REJECTED
          end
        else
          # Abstract syntax rejected:
          pc[:result] = ABSTRACT_SYNTAX_REJECTED
        end
      end
      return info, some_approved, test_only
    end

    # Set the default valid abstract syntaxes and transfer syntaxes for our SCP.
    #
    def set_default_accepted_syntaxes
      @accepted_transfer_syntaxes, @accepted_abstract_syntaxes = LIBRARY.extract_transfer_syntaxes_and_sop_classes
    end

  end # of class
end # of module