# encoding: ASCII-8BIT

# Compatibility specification. Ruby DICOM should be able to read and write all these sample DICOM files successfully.
# Only reading files checked yet.

require 'spec_helper'


module DICOM

  describe DObject do

    before :each do
      DICOM.logger = Logger.new(STDOUT)
      DICOM.logger.level = Logger::FATAL
    end

    describe "::read" do

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.read?.should be_true
        dcm.count.should eql 83
        dcm.count_all.should eql 83
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        dcm.read?.should be_true
        dcm.count.should eql 85
        dcm.count_all.should eql 85
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        dcm.read?.should be_true
        dcm.count.should eql 44
        dcm.count_all.should eql 44
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL)
        dcm.read?.should be_true
        dcm.count.should eql 33
        dcm.count_all.should eql 33
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON)
        dcm.read?.should be_true
        dcm.count.should eql 152
        dcm.count_all.should eql 177
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_RTDOSE_16BIT_MONO2_3D_VOLUME)
        dcm.read?.should be_true
        dcm.count.should eql 85
        dcm.count_all.should eql 139
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        dcm.read?.should be_true
        dcm.count.should eql 97
        dcm.count_all.should eql 123
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME)
        dcm.read?.should be_true
        dcm.count.should eql 45
        dcm.count_all.should eql 56
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_RLE_MONO2)
        dcm.read?.should be_true
        dcm.count.should eql 104
        dcm.count_all.should eql 130
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
        dcm.read?.should be_true
        dcm.count.should eql 78
        dcm.count_all.should eql 80
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME)
        dcm.read?.should be_true
        dcm.count.should eql 55
        dcm.count_all.should eql 64
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_NO_HEADER)
        dcm.read?.should be_true
        dcm.count.should eql 90
        dcm.count_all.should eql 116
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_AT_NO_VALUE)
        dcm.read?.should be_true
        dcm.count.should eql 42
        dcm.count_all.should eql 42
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_AT_INVALID)
        dcm.read?.should be_true
        dcm.count.should eql 42
        dcm.count_all.should eql 42
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_UTF8)
        dcm.read?.should be_true
        dcm.count.should eql 13
        dcm.count_all.should eql 13
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_ISO8859_1)
        dcm.read?.should be_true
        dcm.count.should eql 14
        dcm.count_all.should eql 14
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_DUPLICATES)
        dcm.read?.should be_true
        dcm.count.should eql 12
        dcm.count_all.should eql 14
      end

    end

  end

end