# encoding: ASCII-8BIT

require 'spec_helper'

module DICOM

  describe self do

    it "should have defined a default image processor" do
      DICOM.image_processor.should eql :rmagick
    end

    it "should allow alternative image processors to be defined" do
      DICOM.image_processor = :mini_magick
      DICOM.image_processor.should eql :mini_magick
    end

  end
end