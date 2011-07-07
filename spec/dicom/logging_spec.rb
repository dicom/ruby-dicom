require 'spec_helper'
require 'logger'

module DICOM

  describe "Logging capabilities with logger" do

    it "should be able to log to a file" do
      DICOM.logger = Logger.new('logfile.log')
      DICOM.logger.info "test"
      File.open('logfile.log').readlines.last.should =~ /INFO.*test/
    end

    it "should be able to change logging level" do
      DICOM.logger.level.should == Logger::DEBUG
      DICOM.logger.level = Logger::FATAL
      DICOM.logger.level.should == Logger::FATAL
    end

    after(:each) do
      FileUtils.rm 'logfile.log' if File.file?('logfile.log') 
    end

  end

end
