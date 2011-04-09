# encoding: ASCII-8BIT

# Specification for the image methods using the MiniMagick wrapper as the image processor.

require 'spec_helper'
require 'mini_magick'
# NB! This mini_magick implementation uses some features which are not yet publicly available.
# The situation will be resolved before the next gem release.


module DICOM

  describe SuperItem, "#get_image_magick" do

    before :each do
      DICOM.image_processor = :mini_magick
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

    it "should read the pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_magick.should be_a(MiniMagick::Image)
    end

  end
end