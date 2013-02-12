# encoding: UTF-8

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

    context "#generate_uid" do

      it "should return a UID string" do
        uid = DICOM.generate_uid
        uid.should be_a String
        uid.should match /^[0-9]+([\\.]+|[0-9]+)*$/
      end

      it "should use the UID_ROOT constant when called without parameters" do
        uid = DICOM.generate_uid
        uid.include?(UID_ROOT).should be_true
        uid.index(UID_ROOT).should eql 0
      end

      it "should use the uid and prefix arguments, properly joined by dots" do
        root = "1.999"
        prefix = "6"
        uid = DICOM.generate_uid(root, prefix)
        uid.include?("#{root}.#{prefix}.").should be_true
      end

    end

  end
end