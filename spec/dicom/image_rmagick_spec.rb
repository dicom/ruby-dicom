# encoding: ASCII-8BIT

# Specification for the image methods using the RMagick interface as the image processor.

require 'spec_helper'
require 'RMagick'


module DICOM

  describe SuperItem, "#get_image_magick [using :rmagick]" do

    before :each do
      DICOM.image_processor = :rmagick
    end

    it "should return nil if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      obj.get_image_magick.should be_nil
    end

    it "should return false if it is not able to decompress compressed pixel data" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj["0002,0010"].value = rand(10**10).to_s
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      obj.get_image_magick.should be_false
    end

    it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
    end

    it "should decompress the RLE encoded pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_EXPLICIT_MR_RLE_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
    end

    it "should return false when not suceeding in decompressing the pixel data of this DICOM file" do
      obj = DObject.new(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should eql false
    end

    it "should read the pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
    end

    it "should process the pixel data according to the :level parameter and return an image object" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      image = obj.get_image_magick(:level => true)
      image.should be_a(Magick::Image)
    end

  end


  describe SuperItem, "#get_images_magick [using :rmagick]" do

    before :each do
      DICOM.image_processor = :rmagick
    end

    it "should return an emtpy array if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      images = obj.get_images_magick
      images.should be_an(Array)
      images.length.should eql 0
    end

    it "should return an empty array if it is not able to decompress compressed pixel data" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj["0002,0010"].value = rand(10**10).to_s
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      images = obj.get_images_magick
      images.should be_an(Array)
      images.length.should eql 0
    end

    it "should return an empty array when not suceeding in decompressing the pixel data of this DICOM file" do
      obj = DObject.new(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_an(Array)
      images.length.should eql 0
    end

    it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return the image object in an array" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 1
      images.first.should be_a(Magick::Image)
    end

    it "should decompress the RLE encoded pixel data of this DICOM file and return the image object in an array" do
      obj = DObject.new(DCM_EXPLICIT_MR_RLE_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 1
      images.first.should be_a(Magick::Image)
    end

    it "should decompress the JPEG2K encoded multiframe pixel data of this DICOM file and return the image objects in an array" do
      obj = DObject.new(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 8
      images.first.should be_a(Magick::Image)
      images.last.should be_a(Magick::Image)
    end

    it "should read the pixel data of this DICOM file and return the image object in an array" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 1
      images.first.should be_a(Magick::Image)
    end

  end
end