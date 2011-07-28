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

    it "should always say DICOM" do
      DICOM.logger = Logger.new('logfile.log')
      DICOM.logger.info "test"
      File.open('logfile.log').readlines.last.should =~ /DICOM:.*test/
    end

    it "should say MARK if I say so" do
      DICOM.logger = Logger.new('logfile.log')
      DICOM.logger.info("MARK") { "test" }
      File.open('logfile.log').readlines.last.should =~ /MARK:.*test/
    end

    it "should say DICOM and MARK depend where it was called" do
      logger = Logger.new('logfile.log')
      logger.progname = "MARK"
      DICOM.logger = logger
      DICOM.logger.info "test"
      File.open('logfile.log').readlines.last.should =~ /DICOM:.*test/
      logger.info "test"
      File.open('logfile.log').readlines.last.should =~ /MARK:.*test/
    end

    it "should be class of ProxyLogger inside and Logger outside of DICOM" do
      logger = Logger.new('logfile.log')
      DICOM.logger = logger
      DICOM.logger.class.should == Logging::ClassMethods::ProxyLogger
      logger.class.should == Logger
    end

    after(:each) do
      FileUtils.rm 'logfile.log' if File.file?('logfile.log') 
    end

  end

end
