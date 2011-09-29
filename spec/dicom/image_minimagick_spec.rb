# encoding: ASCII-8BIT

# Specification for the image methods using the MiniMagick wrapper as the image processor.

require 'spec_helper'
require 'mini_magick'


module DICOM

  describe ImageItem, "#image [using :mini_magick]" do

    before :each do
      DICOM.image_processor = :mini_magick
    end

    it "should return nil if no pixel data is present" do
      obj = DObject.new
      obj.image.should be_nil
    end

    it "should return false if it is not able to decompress compressed pixel data" do
      obj = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      obj["0002,0010"].value = rand(10**10).to_s
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
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