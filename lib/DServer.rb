#    Copyright 2009 Christoffer Lervag

module DICOM

  # This class contains code for setting up a Service Class Provider (SCP),
  # which will act as a simple storage node (a server that receives images).
  class DServer

    attr_accessor :ae, :host_ae, :host_ip, :max_package_size, :port, :timeout, :verbose
    attr_reader :errors, :notices

    # Initialize the instance with a host adress and a port number.
    def initialize(port, options={})
      require 'socket'
      # Required parameters:
      @port = port
      # Optional parameters (and default values):
      @host_ip = host_ip || nil
      @ae =  options[:ae]  || "RUBY_DICOM"
      @lib =  options[:lib]  || DLibrary.new
      @host_ae =  options[:host_ae]  || "DEFAULT"
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
      set_valid_abstract_syntaxes
    end
    
    
    # Add a specified abstract syntax to the list of syntaxes that the server instance will accept.
    def add_abstract_syntax(value)
      if value.is_a?(String)
        @valid_abstract_syntaxes << value
        @valid_abstract_syntaxes.sort!
      else
        add_error("Error: The specified abstract syntax is not a string!")
      end
    end
    
    
    # Print the list of valid abstract syntaxes to the screen.
    def print_syntaxes
      puts "Abstract syntaxes accepted by this SCP:"
      @valid_abstract_syntaxes.each do |syntax|
        puts syntax
      end
    end
    
    
    # Remove a specific abstract syntax from the list of syntaxes that the server instance will accept.
    def remove_abstract_syntax(value)
      if value.is_a?(String)
        # Remove it:
        @valid_abstract_syntaxes.delete(value)
      else
        add_error("Error: The specified abstract syntax is not a string!")
      end
    end
    
    
    # Completely clear the list of syntaxes that the server instance will accept.
    def remove_all_abstract_syntaxes
      @valid_abstract_syntaxes = Array.new
    end


    # Start a Storage Content Provider (SCP).
    # This service will receive and store DICOM files in a specified folder.
    def start_scp(path)
      add_notice("Starting SCP server...")
      add_notice("*********************************")
      # Initiate server:
      @scp = TCPServer.new(@port)
      # Use a loop to listen for incoming messages:
      loop do
        Thread.start(@scp.accept) do |session|
          # Initialize the network package handler for this session:
          link = Link.new(:host_ae => @host_ae, :max_package_size => @max_package_size, :timeout => @timeout, :verbose => @verbose)
          add_notice("Connection established (name: #{session.peeraddr[2]}, ip: #{session.peeraddr[3]})")
          # Receive an incoming message:
          segments = link.receive_single_transmission(session)
          info = segments.first
          # Interpret the received message:
          if info[:valid]
            association_error = check_association_request(info)
            unless association_error
              syntax_result = check_syntax_requests(info)
              link.handle_association_accept(session, info, syntax_result)
              if syntax_result == "00" # Normal (no error)
                add_notice("An incoming association request and its abstract syntax has been accepted.")
                if info[:abstract_syntax] == "1.2.840.10008.1.1"
                  # Verification SOP Class (used for testing connections):
                  link.handle_release(session)
                else
                  # Process the incoming data:
                  file_path = link.handle_incoming_data(session, path)
                  add_notice("DICOM file saved to: " + file_path)
                  # Send a receipt for received data:
                  link.handle_response(session)
                  # Release the connection:
                  link.handle_release(session)
                end
              else
                # Abstract syntax in the incoming request was not accepted:
                add_notice("An incoming association request was accepted, but it's abstract syntax was rejected. (#{abstract_syntax})")
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
    end


    # Following methods are private:
    private


    # Adds a warning or error message to the instance array holding messages, and if verbose variable is true, prints the message as well.
    def add_error(error)
      if @verbose
        puts error
      end
      @errors << error
    end


    # Adds a notice (information regarding progress or successful communications) to the instance array,
    # and if verbosity is set for these kinds of messages, prints it to the screen as well.
    def add_notice(notice)
      if @verbose
        puts notice
      end
      @notices << notice
    end
    
    
    # Check if the association request is formally correct.
    # Things that can be checked here, are:
    # Application context name, calling AE title, called AE title
    # Error codes are given in the official dicom document, part 08_08, page 41
    def check_association_request(info)
      error = nil
      # For the moment there is no control on AE titles.
      # Check that Application context name is as expected:
      if info[:application_context] != "1.2.840.10008.3.1.1.1"
        error = "02" # application context name not supported
        add_error("Warning: Application context not recognised in the incoming association request. (#{info[:application_context]})")
      end
      return error
    end
    
    
    # Check if the requested abstract syntax & transfer syntax are supported:
    # Error codes are given in the official dicom document, part 08_08, page 39
    def check_syntax_requests(info)
      result = "00" # (no error)
      # We will accept any transfer syntax (as long as it is recognized in the library):
      # (Weakness: Only checking the first occuring transfer syntax for now)
      transfer_syntax = info[:ts].first[:transfer_syntax]
      unless @lib.check_ts_validity(transfer_syntax)
        result = "04" # transfer syntax not supported
        add_error("Warning: Unsupported transfer syntax received in incoming association request. (#{transfer_syntax})")
      end
      # Check that abstract syntax is among the ones that have been set as valid for this server instance:
      abstract_syntax = info[:abstract_syntax]
      unless @valid_abstract_syntaxes.include?(abstract_syntax)
        result = "03" # abstract syntax not supported
      end
      return result
    end
    
    
    # Set the default valid abstract syntaxes for our SCP.
    def set_valid_abstract_syntaxes
      @valid_abstract_syntaxes = [
        "1.2.840.10008.1.1", # "Verification SOP Class"
        "1.2.840.10008.5.1.4.1.1.1", # "Computed Radiography Image Storage"
        "1.2.840.10008.5.1.4.1.1.1.1", # "Digital X-Ray Image Storage - For Presentation"
        "1.2.840.10008.5.1.4.1.1.1.1.1", # "Digital X-Ray Image Storage - For Processing"
        "1.2.840.10008.5.1.4.1.1.1.2", # "Digital Mammography X-Ray Image Storage - For Presentation"
        "1.2.840.10008.5.1.4.1.1.1.2.1", # "Digital Mammography X-Ray Image Storage - For Processing"
        "1.2.840.10008.5.1.4.1.1.1.3", # "Digital Intra-oral X-Ray Image Storage - For Presentation"
        "1.2.840.10008.5.1.4.1.1.1.3.1", # "Digital Intra-oral X-Ray Image Storage - For Processing"
        "1.2.840.10008.5.1.4.1.1.2", # "CT Image Storage"
        "1.2.840.10008.5.1.4.1.1.2.1", # "Enhanced CT Image Storage"
        "1.2.840.10008.5.1.4.1.1.3", # "Ultrasound Multi-frame Image Storage" # RET
        "1.2.840.10008.5.1.4.1.1.3.1", # "Ultrasound Multi-frame Image Storage"
        "1.2.840.10008.5.1.4.1.1.4", # "MR Image Storage"
        "1.2.840.10008.5.1.4.1.1.4.1", # "Enhanced MR Image Storage"
        "1.2.840.10008.5.1.4.1.1.4.2", # "MR Spectroscopy Storage"
        "1.2.840.10008.5.1.4.1.1.5", # "Nuclear Medicine Image Storage"
        "1.2.840.10008.5.1.4.1.1.6", # "Ultrasound Image Storage"
        "1.2.840.10008.5.1.4.1.1.6.1", # "Ultrasound Image Storage"
        "1.2.840.10008.5.1.4.1.1.7", # "Secondary Capture Image Storage"
        "1.2.840.10008.5.1.4.1.1.7.1", # "Multi-frame Single Bit Secondary Capture Image Storage"
        "1.2.840.10008.5.1.4.1.1.7.2", # "Multi-frame Grayscale Byte Secondary Capture Image Storage"
        "1.2.840.10008.5.1.4.1.1.7.3", # "Multi-frame Grayscale Word Secondary Capture Image Storage"
        "1.2.840.10008.5.1.4.1.1.7.4", # "Multi-frame True Color Secondary Capture Image Storage"
        "1.2.840.10008.5.1.4.1.1.8", # "Standalone Overlay Storage" # RET
        "1.2.840.10008.5.1.4.1.1.9", # "Standalone Curve Storage" # RET
        "1.2.840.10008.5.1.4.1.1.9.1", # "Waveform Storage - Trial" # RET
        "1.2.840.10008.5.1.4.1.1.9.1.1", # "12-lead ECG Waveform Storage"
        "1.2.840.10008.5.1.4.1.1.9.1.2", # "General ECG Waveform Storage"
        "1.2.840.10008.5.1.4.1.1.9.1.3", # "Ambulatory ECG Waveform Storage"
        "1.2.840.10008.5.1.4.1.1.9.2.1", # "Hemodynamic Waveform Storage"
        "1.2.840.10008.5.1.4.1.1.9.3.1", # "Cardiac Electrophysiology Waveform Storage"
        "1.2.840.10008.5.1.4.1.1.9.4.1", # "Basic Voice Audio Waveform Storage"
        "1.2.840.10008.5.1.4.1.1.10", # "Standalone Modality LUT Storage" # RET
        "1.2.840.10008.5.1.4.1.1.11", # "Standalone VOI LUT Storage" # RET
        "1.2.840.10008.5.1.4.1.1.11.1", # "Grayscale Softcopy Presentation State Storage SOP Class"
        "1.2.840.10008.5.1.4.1.1.11.2", # "Color Softcopy Presentation State Storage SOP Class"
        "1.2.840.10008.5.1.4.1.1.11.3", # "Pseudo-Color Softcopy Presentation State Storage SOP Class"
        "1.2.840.10008.5.1.4.1.1.11.4", # "Blending Softcopy Presentation State Storage SOP Class"
        "1.2.840.10008.5.1.4.1.1.12.1", # "X-Ray Angiographic Image Storage"
        "1.2.840.10008.5.1.4.1.1.12.1.1", # "Enhanced XA Image Storage"
        "1.2.840.10008.5.1.4.1.1.12.2", # "X-Ray Radiofluoroscopic Image Storage"
        "1.2.840.10008.5.1.4.1.1.12.2.1", # "Enhanced XRF Image Storage"
        "1.2.840.10008.5.1.4.1.1.13.1.1", # "X-Ray 3D Angiographic Image Storage"
        "1.2.840.10008.5.1.4.1.1.13.1.2", # "X-Ray 3D Craniofacial Image Storage"
        "1.2.840.10008.5.1.4.1.1.12.3", # "X-Ray Angiographic Bi-Plane Image Storage" # RET
        "1.2.840.10008.5.1.4.1.1.20", # "Nuclear Medicine Image Storage"
        "1.2.840.10008.5.1.4.1.1.66", # "Raw Data Storage"
        "1.2.840.10008.5.1.4.1.1.66.1", # "Spatial Registration Storage"
        "1.2.840.10008.5.1.4.1.1.66.2", # "Spatial Fiducials Storage"
        "1.2.840.10008.5.1.4.1.1.66.3", # "Deformable Spatial Registration Storage"
        "1.2.840.10008.5.1.4.1.1.66.4", # "Segmentation Storage"
        "1.2.840.10008.5.1.4.1.1.67", # "Real World Value Mapping Storage"
        "1.2.840.10008.5.1.4.1.1.77.1", # "VL Image Storage - Trial" # RET
        "1.2.840.10008.5.1.4.1.1.77.2", # "VL Multi-frame Image Storage - Trial" # RET
        "1.2.840.10008.5.1.4.1.1.77.1.1", # "VL Endoscopic Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.1.1", # "Video Endoscopic Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.2", # "VL Microscopic Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.2.1", # "Video Microscopic Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.3", # "VL Slide-Coordinates Microscopic Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.4", # "VL Photographic Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.4.1", # "Video Photographic Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.5.1", # "Ophthalmic Photography 8 Bit Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.5.2", # "Ophthalmic Photography 16 Bit Image Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.5.3", # "Stereometric Relationship Storage"
        "1.2.840.10008.5.1.4.1.1.77.1.5.4", # "Ophthalmic Tomography Image Storage"
        "1.2.840.10008.5.1.4.1.1.88.1", # "Text SR Storage - Trial" # RET
        "1.2.840.10008.5.1.4.1.1.88.2", # "Audio SR Storage - Trial" # RET
        "1.2.840.10008.5.1.4.1.1.88.3", # "Detail SR Storage - Trial" # RET
        "1.2.840.10008.5.1.4.1.1.88.4", # "Comprehensive SR Storage - Trial" # RET
        "1.2.840.10008.5.1.4.1.1.88.11", # "Basic Text SR Storage"
        "1.2.840.10008.5.1.4.1.1.88.22", # "Enhanced SR Storage"
        "1.2.840.10008.5.1.4.1.1.88.33", # "Comprehensive SR Storage"
        "1.2.840.10008.5.1.4.1.1.88.40", # "Procedure Log Storage"
        "1.2.840.10008.5.1.4.1.1.88.50", # "Mammography CAD SR Storage"
        "1.2.840.10008.5.1.4.1.1.88.59", # "Key Object Selection Document Storage"
        "1.2.840.10008.5.1.4.1.1.88.65", # "Chest CAD SR Storage"
        "1.2.840.10008.5.1.4.1.1.88.67", # "X-Ray Radiation Dose SR Storage"
        "1.2.840.10008.5.1.4.1.1.104.1", # "Encapsulated PDF Storage"
        "1.2.840.10008.5.1.4.1.1.104.2", # "Encapsulated CDA Storage"
        "1.2.840.10008.5.1.4.1.1.128", # "Positron Emission Tomography Image Storage"
        "1.2.840.10008.5.1.4.1.1.129", # "Standalone PET Curve Storage" # RET
        "1.2.840.10008.5.1.4.1.1.481.1", # "RT Image Storage"
        "1.2.840.10008.5.1.4.1.1.481.2", # "RT Dose Storage"
        "1.2.840.10008.5.1.4.1.1.481.3", # "RT Structure Set Storage"
        "1.2.840.10008.5.1.4.1.1.481.4", # "RT Beams Treatment Record Storage"
        "1.2.840.10008.5.1.4.1.1.481.5", # "RT Plan Storage"
        "1.2.840.10008.5.1.4.1.1.481.6", # "RT Brachy Treatment Record Storage"
        "1.2.840.10008.5.1.4.1.1.481.7", # "RT Treatment Summary Record Storage"
        "1.2.840.10008.5.1.4.1.1.481.8", # "RT Ion Plan Storage"
        "1.2.840.10008.5.1.4.1.1.481.9" # "RT Ion Beams Treatment Record Storage"
      ]
    end


  end
end