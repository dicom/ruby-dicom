module DICOM

  # This module handles logging functionality
  #
  # Logging functionality uses standard library's Logger.
  #
  # === Examples
  #
  #   require 'dicom'
  #   include DICOM
  #   require 'logger'
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
  #   For more information please read the Logger documentation.
  #

  module Logging
    require "logger"

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      # logger class instance
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
        @@logger = l
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
            Rails.logger
          else
            logger = Logger.new(STDOUT)
            logger.level = Logger::INFO
            logger.progname = "DICOM"
            logger
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
