module DICOM

  # This module handles logging functionality
  #
  module Logging
    require "logger"

    @logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)

    def self.logger=(obj)
      @logger = obj
    end

    def self.logger
      @logger
    end
  end
end
