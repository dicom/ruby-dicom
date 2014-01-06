# encoding: UTF-8

require 'spec_helper'


module DICOM

  describe "Logger" do

    it "should be able to log to a file" do
      DICOM.logger = Logger.new(LOGDIR + 'logfile1.log')
      DICOM.logger.info("test")
      expect(File.open(LOGDIR + 'logfile1.log').readlines.last).to match(/INFO.*test/)
    end

    it "should be able to change the logging level" do
      expect(DICOM.logger.level).to eq(Logger::DEBUG)
      DICOM.logger.level = Logger::FATAL
      expect(DICOM.logger.level).to eq(Logger::FATAL)
    end

    it "should always say DICOM (for progname) when used within the DICOM module" do
      DICOM.logger = Logger.new(LOGDIR + 'logfile2.log')
      DICOM.logger.info("test")
      expect(File.open(LOGDIR + 'logfile2.log').readlines.last).to match(/DICOM:.*test/)
    end

    it "should use MARK (for progname) if I explicitly tell it to" do
      DICOM.logger = Logger.new(LOGDIR + 'logfile3.log')
      DICOM.logger.info("MARK") { "test" }
      expect(File.open(LOGDIR + 'logfile3.log').readlines.last).to match(/MARK:.*test/)
    end

    it "should use progname DICOM and MARK depending on where it was called" do
      logger = Logger.new(LOGDIR + 'logfile4.log')
      logger.progname = "MARK"
      DICOM.logger = logger
      DICOM.logger.info("test")
      expect(File.open(LOGDIR + 'logfile4.log').readlines.last).to match(/DICOM:.*test/)
      logger.info("test")
      expect(File.open(LOGDIR + 'logfile4.log').readlines.last).to match(/MARK:.*test/)
    end

    it "should be a class of ProxyLogger inside the DICOM module and Logger outside" do
      logger = Logger.new(LOGDIR + 'logfile5.log')
      DICOM.logger = logger
      expect(DICOM.logger.class).to eq(Logging::ClassMethods::ProxyLogger)
      expect(logger.class).to eq(Logger)
    end

    it "should not print messages when a non-verbose mode has been set (Logger::FATAL)" do
      DICOM.logger = Logger.new(LOGDIR + 'logfile6.log')
      DICOM.logger.level = Logger::FATAL
      DICOM.logger.debug("Debugging")
      DICOM.logger.info("Information")
      DICOM.logger.warn("Warning")
      DICOM.logger.error("Errors")
      expect(File.open(LOGDIR + 'logfile6.log').readlines.last.include?('DICOM')).to be_false
    end

    it "should print messages when a verbose mode has been set (Logger::DEBUG)" do
      DICOM.logger = Logger.new(LOGDIR + 'logfile7.log')
      DICOM.logger.level = Logger::DEBUG
      DICOM.logger.debug("Debugging")
      DICOM.logger.info("Information")
      DICOM.logger.warn("Warning")
      DICOM.logger.error("Errors")
      expect(File.open(LOGDIR + 'logfile7.log').readlines.last.include?('DICOM')).to be_true
    end

  end

end
