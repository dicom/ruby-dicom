# encoding: UTF-8

require 'spec_helper'


# FIXME: Since the extensions have been merged into the master branch,
# these tests should be distributed to their respective class files.
#
module DICOM

  describe DObject, " (Extensions)" do

    before(:each) do
      @dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
    end

    it "should have an elements Array" do
      @dcm.elements.should be_an Array
    end

    it "should have a #file_meta_information_group_length" do
      @dcm.file_meta_information_group_length.value.should_not be_nil
    end

    it "should not respond to an arbitrary method name that should not work" do
      @dcm.should_not respond_to :any_method_name_that_should_not_work
    end

    it "should have a number of frames" do
      @dcm.num_frames.should be >= 1
    end

    it "should query the DICOM object for the existence of a tag using <methodized-name>? returning true if it exists" do
       @dcm.sop_instance_uid?.should be_true
    end

    it "should query the DICOM object for the existence of a tag using <methodized-name>? returning false if it doesnt exist" do
      @dcm.sop_instance_uid = nil
      @dcm.sop_instance_uid?.should be_false
    end

    it "should query the DICOM object for the existence of a tag using <methodized-name>? returning true if it exists" do
      @dcm.sop_instance_uid = "1.2.3.4.5.6"
      @dcm.sop_instance_uid?.should be_true
    end

    it "should set the sop_instance_uid to '1.2.3.4.5'" do
      @dcm.sop_instance_uid = "1.2.3.4.5"
      @dcm.sop_instance_uid.value.should eql "1.2.3.4.5"
    end

    it "should delete the sop_instance_uid" do
      @dcm.sop_instance_uid = nil
      @dcm.sop_instance_uid?.should be_false
    end

    it "should set file_meta_information_group_length from an integer value" do
      integer = 12345
      @dcm.file_meta_information_group_length = integer
      @dcm.file_meta_information_group_length.value.should == integer.to_s.to_i
    end

    it "should set sop_instance_uid from a string value" do
      string = "this is a string value"
      @dcm.sop_instance_uid = string
      @dcm.sop_instance_uid.value.should == string.to_s
    end

    it "should set examined_body_thickness from a float value" do
      float = 1267.38991
      @dcm.examined_body_thickness = float
      @dcm.examined_body_thickness.value.should == float.to_s.to_f
    end

    it "should set examined_body_thickness from an integer value" do
      integer = 12345
      @dcm.examined_body_thickness = integer
      @dcm.examined_body_thickness.value.should == integer.to_s.to_f
    end

    it "should create a new element with the given value, using dictionary method name matching" do
      dcm = DObject.new
      dcm.sop_instance_uid = "1.2.3.4.5"
      dcm.value("0008,0018").should eql "1.2.3.4.5"
    end

    # Using dynamic method matching for sequence creation doesn't look as natural as
    # for element creation, but I guess we better have it for consistency.
    it "should create a new sequence, using dictionary method name matching" do
      dcm = DObject.new
      dcm.referenced_image_sequence = true
      dcm["0008,1140"].should be_a Sequence
    end

    # Using dynamic method matching for item creation doesn't look as natural as
    # for element creation, but I guess we better have it for consistency.
    it "should create a new item, using dictionary method name matching" do
      dcm = DObject.new
      dcm.referenced_image_sequence = true
      dcm["0008,1140"].item = true
      dcm["0008,1140"][0].should be_an Item
    end

    it "should create an empty hash when the DICOM object is empty" do
      dcm = DObject.new
      dcm.to_hash.should be_a Hash
      dcm.to_hash.length.should eql 0
    end

    it "should create value-less, one-element hash when the Sequence is child-less" do
      s = Sequence.new("0008,1140")
      s.to_hash.should be_a Hash
      s.to_hash.length.should eql 1
      s.to_hash["0008,1140"].should be_nil
    end

    it "should create a hash with DICOM names as keys" do
      DICOM.key_use_names
      @dcm.to_hash.key?("File Meta Information Group Length").should be_true
    end

    it "should create a hash with DICOM method symbols as keys" do
      DICOM.key_use_method_names
      @dcm.to_hash.key?(:file_meta_information_group_length).should be_true
    end

    it "should create a hash with DICOM tags as keys" do
      DICOM.key_use_tags
      @dcm.to_hash.key?("0002,0000").should be_true
    end

  end


  describe Element, " (Extensions)" do

    context "#to_hash" do

      it "should create a one-element hash with its dictionary name as key" do
        DICOM.key_use_names
        e = Element.new("0018,1310", 512)
        e.to_hash.should be_a Hash
        e.to_hash.length.should eql 1
        e.to_hash.key?("Acquisition Matrix").should be_true
      end

      it "should create a hash with its value as the hash value" do
        DICOM.key_use_names
        value = 512
        e = Element.new("0018,1310", value)
        e.to_hash.value?(value).should be_true
      end

    end

  end


  describe DLibrary, " (Extensions)" do

    context LIBRARY.method(:get_tag) do

      it "should return the tag corresponding to a name" do
        LIBRARY.get_tag("File Meta Information Group Length").should == "0002,0000"
      end

      it "should return nil if the tag does not exist for the given name" do
        LIBRARY.get_tag("This Name Does Not Exist Qwerty").should be_nil
      end

    end

    context LIBRARY.method(:as_method) do

      it "should return the input value as a symbol when that is a method name" do
        LIBRARY.as_method("file_meta_information_group_length").should be :file_meta_information_group_length
      end

      it "should return the method name as a symbol for strings which are names" do
        LIBRARY.as_method("File Meta Information Group Length").should be :file_meta_information_group_length
      end

      it "should return the method name as a symbol for strings which are tags" do
        LIBRARY.as_method("0002,0000").should be :file_meta_information_group_length
      end

      it "should return nil for strings which are non-existant methods" do
        LIBRARY.as_method("this_method_does_not_exist_qwerty").should be_nil
      end

      it "should return nil for strings which are names of non-existant methods" do
        LIBRARY.as_method("This Name Does Not Exist Qwerty").should be_nil
      end

      it "should return nil for strings which are tags not part of the DICOM standard" do
        LIBRARY.as_method("9999,QERT").should be_nil
      end

    end

    context LIBRARY.method(:as_tag) do

      it "should return the input value when that is a tag" do
        LIBRARY.as_tag("0002,0000").should == "0002,0000"
      end

      it "should return the tag for strings which are names" do
        LIBRARY.as_tag("File Meta Information Group Length").should == "0002,0000"
      end

      it "should return the tag for strings which are methods" do
        LIBRARY.as_tag("file_meta_information_group_length").should == "0002,0000"
      end

      it "should return nil for strings which are method names corresponding to non-existant tags" do
        LIBRARY.as_tag("this_method_does_not_exist_qwerty").should be_nil
      end

      it "should return nil for strings which are names corresponding to non-existant tags" do
        LIBRARY.as_tag("This Name Does Not Exist Qwerty").should be_nil
      end

      it "should return nil for strings which non-existant tags" do
        LIBRARY.as_tag("9999,QERT").should be_nil
      end

    end

    context LIBRARY.method(:as_name) do

      it "should return the input value when that is a name" do
        LIBRARY.as_name("File Meta Information Group Length").should == "File Meta Information Group Length"
      end

      it "should return the name for strings which are method names" do
        LIBRARY.as_name("file_meta_information_group_length").should == "File Meta Information Group Length"
      end

      it "should return the name for strings which are tags" do
        LIBRARY.as_name("0002,0000").should == "File Meta Information Group Length"
      end

      it "should return nil for strings which are method names corresponding to non-existant names" do
        LIBRARY.as_name("this_method_does_not_exist_qwerty").should be_nil
      end

      it "should return nil for strings which are non-existant names" do
        LIBRARY.as_name("This Name Does Not Exist Qwerty").should be_nil
      end

      it "should return nil for strings which are tags corresponding to non-existant names" do
        LIBRARY.as_name("9999,QERT").should be_nil
      end

    end

  end


  describe String, " (Extensions)" do

    context "".method(:dicom_methodize) do

      it "should return a method name 'three_d_stuff_and_with_some_weird_characters' for '3d Stuff & with some !? weird !!! characters'" do
        "3d Stuff & with some !? weird !!! characters".dicom_methodize.should == "three_d_stuff_and_with_some_weird_characters"
      end

      it "should return a method name 'three_d_something_its_nice' for '3d (something) it's NICE'" do
        "3d (something) it's NICE".dicom_methodize.should == "three_d_something_its_nice"
      end

      # Comment: How non-ascii characters in method names should be handled is something that may be up for debate.
      it "should return a method name with the non-ascii character preserved" do
        #"hello µValue it's STUPID".dicom_methodize.should == "hello_uvalue_its_stupid" # (alternative spec)
        "hello µValue it's STUPID".dicom_methodize.should == "hello_µvalue_its_stupid"
      end

    end

    context "".method(:dicom_name?) do

      it "should return true if the string looks like a DICOM element name" do
        "This Looks Like A Name".dicom_name?.should be_true
      end

      it "should return false if the string doesnt look like a DICOM element name" do
        "this Doesnt Look like a name".dicom_name?.should be_false
      end

      it "should return false if the string looks like a DICOM method name" do
        "this_looks_like_a_method_name".dicom_name?.should be_false
      end

    end

    context "".method(:dicom_method?) do

      it "should return true if the string looks like a DICOM method name" do
        "this_looks_like_a_method_name".dicom_method?.should be_true
      end

      it "should return false if the string doesnt look like a DICOM method name" do
        "This_doesnt look_like a MethodName".dicom_method?.should be_false
      end

      it "should return false if the string looks like a DICOM element name" do
        "This Looks Like A Name".dicom_method?.should be_false
      end

    end

  end

end