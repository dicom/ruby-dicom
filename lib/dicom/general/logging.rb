module DICOM

  # This module handles logging functionality.
  #
  # Logging functionality uses the Standard library's Logger class.
  # To properly handle progname, which inside the DICOM module is simply
  # "DICOM", in all cases, we use an implementation with a proxy class.
  #
  # @note For more information, please read the Standard library Logger documentation.
  #
  # @example Various logger use cases:
  #   require 'dicom'
  #   include DICOM
  #
  #   # Logging to STDOUT with DEBUG level:
  #   DICOM.logger = Logger.new(STDOUT)
  #   DICOM.logger.level = Logger::DEBUG
  #
  #   # Logging to a file:
  #   DICOM.logger = Logger.new('my_logfile.log')
  #
  #   # Combine an external logger with DICOM:
  #   logger = Logger.new(STDOUT)
  #   logger.progname = "MY_APP"
  #   DICOM.logger = logger
  #   # Now you can call the logger in the following ways:
  #   DICOM.logger.info "Message"               # => "DICOM: Message"
  #   DICOM.logger.info("MY_MODULE) {"Message"} # => "MY_MODULE: Message"
  #   logger.info "Message"                     # => "MY_APP: Message"
  #
  module Logging

    require 'logger'

    # Inclusion hook to make the ClassMethods available to whatever
    # includes the Logging module, i.e. the DICOM module.
    #
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods which the Logging module is extended with.
    #
    module ClassMethods

      # We use our own ProxyLogger to achieve the features wanted for DICOM logging,
      # e.g. using DICOM as progname for messages logged within the DICOM module
      # (for both the Standard logger as well as the Rails logger), while still allowing
      # a custom progname to be used when the logger is called outside the DICOM module.
      #
      class ProxyLogger

        # Creating the ProxyLogger instance.
        #
        # @param [Logger] target a logger instance (e.g. Standard Logger or ActiveSupport::BufferedLogger)
        #
        def initialize(target)
          @target = target
        end

        # Catches missing methods.
        #
        # In our case, the methods of interest are the typical logger methods,
        # i.e. log, info, fatal, error, debug, where the arguments/block are
        # redirected to the logger in a specific way so that our stated logger
        # features are achieved (this behaviour depends on the logger
        # (Rails vs Standard) and in the case of Standard logger,
        # whether or not a block is given).
        #
        # @example Inside the DICOM module or an external class with 'include DICOM::Logging':
        #   logger.info "message"
        #
        # @example Calling from outside the DICOM module:
        #   DICOM.logger.info "message"
        #
        def method_missing(method_name, *args, &block)
          if method_name.to_s =~ /(log|debug|info|warn|error|fatal)/
            # Rails uses it's own buffered logger which does not
            # work with progname + block as the standard logger does:
            if defined?(Rails)
              @target.send(method_name, "DICOM: #{args.first}")
            elsif block_given?
              @target.send(method_name, *args) { yield }
            else
              @target.send(method_name, "DICOM") { args.first }
            end
          else
            @target.send(method_name, *args, &block)
          end
        end

      end

      # The logger class variable (must be initialized
      # before it is referenced by the object setter).
      #
      @@logger = nil

      # The logger object getter.
      #
      # If a logger instance is not pre-defined, it sets up a Standard
      # logger or (if in a Rails environment) the Rails logger.
      #
      # @example Inside the DICOM module (or a class with 'include DICOM::Logging'):
      #   logger # => Logger instance
      #
      # @example Accessing from outside the DICOM module:
      #   DICOM.logger # => Logger instance
      #
      # @return [ProxyLogger] the logger class variable
      #
      def logger
        @@logger ||= lambda {
          if defined?(Rails)
            ProxyLogger.new(Rails.logger)
          else
            l = Logger.new(STDOUT)
            l.level = Logger::INFO
            ProxyLogger.new(l)
          end
        }.call
      end

      # The logger object setter.
      #
      # This method is used to replace the default logger instance with
      # a custom logger of your own.
      #
      # @param [Logger] l a logger instance
      #
      # @example Multiple log files
      #   # Create a logger which ages logfile once it reaches a certain size,
      #   # leaving 10 "old log files" with each file being about 1,024,000 bytes:
      #   DICOM.logger = Logger.new('foo.log', 10, 1024000)
      #
      def logger=(l)
        @@logger = ProxyLogger.new(l)
      end

    end

    # A logger object getter.
    # Forwards the call to the logger class method of the Logging module.
    #
    # @return [ProxyLogger] the logger class variable
    #
    def logger
      self.class.logger
    end

  end

  # Include the Logging module so we can use DICOM.logger.
  include Logging

end