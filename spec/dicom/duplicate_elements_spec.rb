# encoding: UTF-8

require 'spec_helper'

module DICOM

  # In a DICOM file, a given tag is only meant to appear once (at a particular level), with the
  # exception being the Item tag (FFFE,E000) and the Data Set Trailing Padding tag (FFFC,FFFC).
  # A DICOM file containing a duplicate data element or sequence, is thus invalidly encoded,
  # but will be parsed just fine by ruby-dicom (and probably most DICOM libraries).
  # Because ruby-dicom uses a hash based element storage, with tag as key, such duplicates will
  # not co-exist. The only option when such a situation occurs is to either keep the first element
  # instance and disregard the rest, or to always ovewrite the existing instance with the last one.
  #
  describe DObject do

    context "::read" do

      it "should by default keep the original instance(s) when duplicate element(s)/sequence(s) occurs" do
        dcm = DObject.read(DCM_DUPLICATES)
        dcm.value('0010,0010').should eql 'First'
        dcm['3006,0010'][0].value('0020,0052').should eql '11'
        dcm['3006,0010'][0]['3006,0012'][0].value('0008,1150').should eql '11'
        dcm['3006,0020'][0].value('3006,0026').should eql 'First SQ'
      end

      it "should overwrite the original instance(s) when duplicate element(s)/sequence(s) occurs and the :overwrite option is true" do
        dcm = DObject.read(DCM_DUPLICATES, :overwrite => true)
        dcm.value('0010,0010').should eql 'Latest'
        dcm['3006,0010'][0].value('0020,0052').should eql '12'
        dcm['3006,0010'][0]['3006,0012'][0].value('0008,1150').should eql '12'
        dcm['3006,0020'][0].value('3006,0026').should eql 'LatestSQ'
      end

      it "should properly register the top level element that follows the (duplicate) sequence (in default read mode)" do
        dcm = DObject.read(DCM_DUPLICATES)
        dcm.exists?('7200,0100').should be_true
      end

      it "should properly register the top level element that follows the (duplicate) sequence (in overwrite read mode)" do
        dcm = DObject.read(DCM_DUPLICATES, :overwrite => true)
        dcm.exists?('7200,0100').should be_true
      end

      it "should log a warning when encountering duplicate elements" do
        DICOM.logger = mock('Logger')
        DICOM.logger.expects(:warn).at_least_once
        DICOM.logger.stubs(:debug)
        DICOM.logger.stubs(:info)
        DICOM.logger.stubs(:error)
        dcm = DObject.read(DCM_DUPLICATES)
      end

    end
    
    
    after :all do
      DICOM.logger = Logger.new(STDOUT)
      DICOM.logger.level = Logger::FATAL
    end

  end
  
end