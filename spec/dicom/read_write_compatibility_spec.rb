# encoding: UTF-8

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
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 83
        expect(dcm.count_all).to eql 83
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 85
        expect(dcm.count_all).to eql 85
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 44
        expect(dcm.count_all).to eql 44
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 33
        expect(dcm.count_all).to eql 33
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 152
        expect(dcm.count_all).to eql 177
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_RTDOSE_16BIT_MONO2_3D_VOLUME)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 85
        expect(dcm.count_all).to eql 139
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 97
        expect(dcm.count_all).to eql 123
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 45
        expect(dcm.count_all).to eql 56
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_RLE_MONO2)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 104
        expect(dcm.count_all).to eql 130
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 78
        expect(dcm.count_all).to eql 80
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 55
        expect(dcm.count_all).to eql 64
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_NO_HEADER)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 90
        expect(dcm.count_all).to eql 116
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_AT_NO_VALUE)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 42
        expect(dcm.count_all).to eql 42
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_AT_INVALID)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 42
        expect(dcm.count_all).to eql 42
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_UTF8)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 13
        expect(dcm.count_all).to eql 13
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_ISO8859_1)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 14
        expect(dcm.count_all).to eql 14
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        dcm = DObject.read(DCM_DUPLICATES)
        expect(dcm.read?).to be_true
        expect(dcm.count).to eql 13
        expect(dcm.count_all).to eql 20
      end

    end

  end

end