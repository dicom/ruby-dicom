module DICOM

  # This module handles logging functionality
  #
  module Logging
    require "logger"

    # Logging functionality uses standard library's Logger.
    #
    # === Examples
    #
    #   require 'dicom'
    #   include DICOM
    #   require 'logger'
    #
    #   # logging to STDOUT with DEBUG level
    #   Logging.logger = Logger.new(STDOUT)
    #   Logging.level = Logger::DEBUG
    #
    #   # logging to file
    #   Logging.logger = Logger.new('my_logfile.log')
    #
    #   # Examples from Logger doc:
    #
    #   # Create a logger which ages logfile once it reaches a certain
    #   # size. Leave 10 "old log files" and each file is about 1,024,000
    #   # bytes.
    #   # 
    #   Logging.logger = Logger.new('foo.log', 10, 1024000)
    #
    #   #  Create a logger which ages logfile daily/weekly/monthly.
    #   # 
    #   Logging.logger = Logger.new('foo.log', 'daily')
    #   Logging.logger = Logger.new('foo.log', 'weekly')
    #   Logging.logger = Logger.new('foo.log', 'monthly')
    #   
    #
    #   For more information please read the Logger documentation.
    def self.logger=(obj)
      @logger = obj
    end

    def self.logger
      @logger ||= if defined?(Rails) 
                    Rails.logger 
                  else
                    logger = Logger.new(STDOUT)
                    logger.level = Logger::INFO
                    logger
                  end
    end

    def self.level
      @logger.level
    end

    def self.level=(obj)
      @logger.level = obj
    end
  end

end
