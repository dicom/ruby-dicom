require 'spec_helper'
require 'logger'

module DICOM

  describe "Logging capabilities with logger" do

    it "should be able to log to a file" do
      Logging.logger = Logger.new('logfile.log')
      Logging.logger.info "test"
      File.open('logfile.log').readlines.last.should =~ /INFO.*test/
    end

    it "should be able to change logging level" do
      Logging.logger.level.should == Logger::DEBUG
      Logging.logger.level = Logger::FATAL
      Logging.logger.level.should == Logger::FATAL
    end

    after(:each) do
      FileUtils.rm 'logfile.log' if File.file?('logfile.log') 
    end

  end

end
