require 'spec_helper'

module DICOM

  describe "Logging capabilities with logger" do

    it "should be able to reach Logger instance" do
      Logging.logger.class.should == Logger
    end

    it "should be able to log to a file" do
      require "logger"
      Logging.logger = Logger.new('logfile.log')
      Logging.logger.info "test"
      File.open('logfile.log').readlines.last.should =~ /INFO.*test/
    end

    after(:each) do
      FileUtils.rm 'logfile.log' if File.file?('logfile.log') 
    end

  end

end
