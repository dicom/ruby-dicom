module DICOM

  # This module handles logging functionality
  #
  module Logging
    require "logger"

    def self.logger
      @logger ||= if defined?(Rails) 
                    Rails.logger 
                  else
                    logger = Logger.new(STDOUT)
                    logger.level = Logger::WARN
                    logger
                  end
    end

    def self.logger=(obj)
      @logger = obj
    end
  end

end
