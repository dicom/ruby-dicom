module DICOM

  # This module handles logging functionality
  #
  # Logging functionality uses standard library's Logger.
  # To prevent change on progname which inside of DICOM module is simply "DICOM"
  # we use proxy class.
  #
  #
  # === Examples
  #
  #   require 'dicom'
  #   include DICOM
  #
  #   # logging to STDOUT with DEBUG level
  #   DICOM.logger = Logger.new(STDOUT)
  #   DICOM.logger.level = Logger::DEBUG
  #
  #   # logging to file
  #   DICOM.logger = Logger.new('my_logfile.log')
  #
  #   # Examples from Logger doc:
  #
  #   # Create a logger which ages logfile once it reaches a certain
  #   # size. Leave 10 "old log files" and each file is about 1,024,000
  #   # bytes.
  #   #
  #   DICOM.logger = Logger.new('foo.log', 10, 1024000)
  #
  #   #  Create a logger which ages logfile daily/weekly/monthly.
  #   #
  #   DICOM.logger = Logger.new('foo.log', 'daily')
  #   DICOM.logger = Logger.new('foo.log', 'weekly')
  #   DICOM.logger = Logger.new('foo.log', 'monthly')
  #
  #
  #   # Combine external logger with DICOM
  #   #
  #   logger = Logger.new(STDOUT)
  #   logger.progname = "MY_APP"
  #   DICOM.logger = logger
  #   # now you can call
  #   DICOM.logger.info "Message"            # => "DICOM: Message"
  #   DICOM.logger.info("MY_MODULE)"Message" # => "MY_MODULE: Message"
  #   logger.info "Message"                  # => "MY_APP: Message"
  #
  #   For more information please read the Logger documentation.
  #

  module Logging
    require "logger"

    def self.included(base)
      base.extend(ClassMethods)
    end


    module ClassMethods

      class ProxyLogger
        def initialize(target_object)
          @target = target_object
        end

        def method_missing(method_name, *args, &block)
          if method_name.to_s =~ /(log|info|fatal|error|debug)/
            if block_given?
              @target.send(method_name, *args) { yield }
            else
              @target.send(method_name, "DICOM") { args.first }
            end
          else
            @target.send(method_name, *args, &block)
          end
        end
      end

      # logger class instance (covered by proxy)
      #
      @@logger = nil

      # logger object setter
      #
      # === Example
      #
      # # inside a class with "include Logging"
      # logger.info "message"
      #
      # # outside
      # DICOM.logger.info "message"
      #
      def logger=(l)
        @@logger = ProxyLogger.new(l)
      end

      # logger object getter
      #
      # === Example
      #
      # # inside a class with "include Logging"
      # logger # => Logger instance
      #
      # # outside
      # DICOM.logger # => Logger instance
      #
      def logger
        @@logger ||= lambda {
          if defined?(Rails)
            ProxyLogger.new Rails.logger
          else
            l = Logger.new(STDOUT)
            l.level = Logger::INFO
            ProxyLogger.new l
          end
        }.call
      end
    end

    def logger
      self.class.logger
    end

    def logger=(l)
      self.class.logger = l
    end

  end

  # so we can use DICOM.logger
  include Logging
end
