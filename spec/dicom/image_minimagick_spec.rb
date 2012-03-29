# encoding: ASCII-8BIT

# Specification for the image methods using the MiniMagick wrapper as the image processor.

require 'spec_helper'
require 'mini_magick'


module DICOM

  describe ImageItem do

    describe "#image [using :mini_magick]" do

      before :each do
        DICOM.image_processor = :mini_magick
      end

      it "should log a warning when it fails to decompress compressed pixel data" do
        obj = DObject.read(DCM_INVALID_COMPRESSION)
        DICOM.logger.expects(:warn)
        obj.image
      end

      it "should return false when it fails to decompress compressed pixel data" do
        obj = DObject.read(DCM_INVALID_COMPRESSION)
        obj.image.should be_false
      end

      it "should read the pixel data of this DICOM file and return an image object" do
        obj = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        image = obj.image
        image.should be_a(MiniMagick::Image)
      end

      it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return an image object" do
        obj = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        image = obj.image
        image.should be_a(MiniMagick::Image)
      end

      it "should decompress the RLE encoded pixel data of this DICOM file and return an image object" do
        obj = DObject.read(DCM_EXPLICIT_MR_RLE_MONO2)
        image = obj.image
        image.should be_a(MiniMagick::Image)
      end

      it "should return false when not suceeding in decompressing the pixel data of this DICOM file" do
        obj = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
        image = obj.image
        image.should eql false
      end

    end

  end

end