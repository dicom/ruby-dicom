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
    
    
    context "#load" do

      it "should return an empty array when given an invalid DICOM file path" do
        ary = DICOM.load('./invalid_file.dcm')
        ary.should eql []
      end
      
      it "should return a DObject instance in an array when given a DICOM binary string" do
        str = File.open(DCM_ISO8859_1, "rb") { |f| f.read }
        ary = DICOM.load(str)
        ary.should eql [DObject.parse(str)]
      end
      
      it "should return a DObject instance in an array when given a path to a DICOM file" do
        file = DCM_ISO8859_1
        ary = DICOM.load(file)
        ary.should eql [DObject.read(file)]
      end
      
      it "should return the DObject instance in an array when given a DObject instance" do
        dcm = DObject.read(DCM_ISO8859_1)
        ary = DICOM.load(dcm)
        ary.should eql [dcm]
      end
      
      it "should return a DObject instance in an array when given an array with a DICOM binary string" do
        str = File.open(DCM_ISO8859_1, "rb") { |f| f.read }
        ary = DICOM.load([str])
        ary.should eql [DObject.parse(str)]
      end
      
      it "should return a DObject instance in an array when given an array with a path to a DICOM file" do
        file = DCM_ISO8859_1
        ary = DICOM.load([file])
        ary.should eql [DObject.read(file)]
      end
      
      it "should return the DObject instance in an array when given an array with a DObject instance" do
        dcm = DObject.read(DCM_ISO8859_1)
        ary = DICOM.load([dcm])
        ary.should eql [dcm]
      end
      
      it "should return a one-element array with the valid DObject when given an array with one valid DICOM file path and one invalid file path" do
        ary = DICOM.load([DCM_ISO8859_1, './invalid_file.dcm'])
        ary.should eql [DObject.read(DCM_ISO8859_1)]
      end
      
      it "should return an array with three DObject instance when given an array with a mix of DICOM file path, binary string and DObject instance" do
        file = DCM_ISO8859_1
        str = File.open(file, "rb") { |f| f.read }
        dcm = DObject.read(file)
        ary = DICOM.load([str, file, dcm])
        ary.should eql [DObject.read(file), DObject.read(file), DObject.read(file)]
      end

    end

  end
end