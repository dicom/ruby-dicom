# encoding: UTF-8

require 'spec_helper'


# FIXME: Since the extensions have been merged into the master branch,
# these tests should be distributed to their respective class files.
#
module DICOM

  context "With regards to dynamic method names" do

    describe DObject do

      before(:example) do
        @dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      end

      it "should have an elements Array" do
        expect(@dcm.elements).to be_an Array
      end

      it "should have a #file_meta_information_group_length" do
        expect(@dcm.file_meta_information_group_length.value).not_to be_nil
      end

      it "should not respond to an arbitrary method name that should not work" do
        expect(@dcm).not_to respond_to :any_method_name_that_should_not_work
      end

      it "should have a number of frames" do
        expect(@dcm.num_frames).to be >= 1
      end

      it "should query the DICOM object for the existence of a tag using <methodized-name>? returning true if it exists" do
         expect(@dcm.sop_instance_uid?).to be_truthy
      end

      it "should query the DICOM object for the existence of a tag using <methodized-name>? returning false if it doesnt exist" do
        @dcm.sop_instance_uid = nil
        expect(@dcm.sop_instance_uid?).to be_falsey
      end

      it "should query the DICOM object for the existence of a tag using <methodized-name>? returning true if it exists" do
        @dcm.sop_instance_uid = "1.2.3.4.5.6"
        expect(@dcm.sop_instance_uid?).to be_truthy
      end

      it "should set the sop_instance_uid to '1.2.3.4.5'" do
        @dcm.sop_instance_uid = "1.2.3.4.5"
        expect(@dcm.sop_instance_uid.value).to eql "1.2.3.4.5"
      end

      it "should delete the sop_instance_uid" do
        @dcm.sop_instance_uid = nil
        expect(@dcm.sop_instance_uid?).to be_falsey
      end

      it "should set file_meta_information_group_length from an integer value" do
        integer = 12345
        @dcm.file_meta_information_group_length = integer
        expect(@dcm.file_meta_information_group_length.value).to eq(integer.to_s.to_i)
      end

      it "should set sop_instance_uid from a string value" do
        string = "this is a string value"
        @dcm.sop_instance_uid = string
        expect(@dcm.sop_instance_uid.value).to eq(string.to_s)
      end

      it "should set examined_body_thickness from a float value" do
        float = 1267.38991
        @dcm.examined_body_thickness = float
        expect(@dcm.examined_body_thickness.value).to eq(float.to_s.to_f)
      end

      it "should set examined_body_thickness from an integer value" do
        integer = 12345
        @dcm.examined_body_thickness = integer
        expect(@dcm.examined_body_thickness.value).to eq(integer.to_s.to_f)
      end

      it "should create a new element with the given value, using dictionary method name matching" do
        dcm = DObject.new
        dcm.sop_instance_uid = "1.2.3.4.5"
        expect(dcm.value("0008,0018")).to eql "1.2.3.4.5"
      end

      # Using dynamic method matching for sequence creation doesn't look as natural as
      # for element creation, but I guess we better have it for consistency.
      it "should create a new sequence, using dictionary method name matching" do
        dcm = DObject.new
        dcm.referenced_image_sequence = true
        expect(dcm["0008,1140"]).to be_a Sequence
      end

      # Using dynamic method matching for item creation doesn't look as natural as
      # for element creation, but I guess we better have it for consistency.
      it "should create a new item, using dictionary method name matching" do
        dcm = DObject.new
        dcm.referenced_image_sequence = true
        dcm["0008,1140"].item = true
        expect(dcm["0008,1140"][0]).to be_an Item
      end

      it "should create an empty hash when the DICOM object is empty" do
        dcm = DObject.new
        expect(dcm.to_hash).to be_a Hash
        expect(dcm.to_hash.length).to eql 0
      end

      it "should create value-less, one-element hash when the Sequence is child-less" do
        s = Sequence.new("0008,1140")
        expect(s.to_hash).to be_a Hash
        expect(s.to_hash.length).to eql 1
        expect(s.to_hash["0008,1140"]).to be_nil
      end

      it "should create a hash with DICOM names as keys" do
        DICOM.key_use_names
        expect(@dcm.to_hash.key?("File Meta Information Group Length")).to be_truthy
      end

      it "should create a hash with DICOM method symbols as keys" do
        DICOM.key_use_method_names
        expect(@dcm.to_hash.key?(:file_meta_information_group_length)).to be_truthy
      end

      it "should create a hash with DICOM tags as keys" do
        DICOM.key_use_tags
        expect(@dcm.to_hash.key?("0002,0000")).to be_truthy
      end

    end


    describe Element do

      describe "#to_hash" do

        it "should create a one-element hash with its dictionary name as key" do
          DICOM.key_use_names
          e = Element.new("0018,1310", 512)
          expect(e.to_hash).to be_a Hash
          expect(e.to_hash.length).to eql 1
          expect(e.to_hash.key?("Acquisition Matrix")).to be_truthy
        end

        it "should create a hash with its value as the hash value" do
          DICOM.key_use_names
          value = 512
          e = Element.new("0018,1310", value)
          expect(e.to_hash.value?(value)).to be_truthy
        end

      end

    end


    describe DLibrary do

      describe "::get_tag" do

        it "should return the tag corresponding to a name" do
          expect(LIBRARY.get_tag("File Meta Information Group Length")).to eq("0002,0000")
        end

        it "should return nil if the tag does not exist for the given name" do
          expect(LIBRARY.get_tag("This Name Does Not Exist Qwerty")).to be_nil
        end

      end

      describe "::as_method" do

        it "should return the input value as a symbol when that is a method name" do
          expect(LIBRARY.as_method("file_meta_information_group_length")).to be :file_meta_information_group_length
        end

        it "should return the method name as a symbol for strings which are names" do
          expect(LIBRARY.as_method("File Meta Information Group Length")).to be :file_meta_information_group_length
        end

        it "should return the method name as a symbol for strings which are tags" do
          expect(LIBRARY.as_method("0002,0000")).to be :file_meta_information_group_length
        end

        it "should return nil for strings which are non-existant methods" do
          expect(LIBRARY.as_method("this_method_does_not_exist_qwerty")).to be_nil
        end

        it "should return nil for strings which are names of non-existant methods" do
          expect(LIBRARY.as_method("This Name Does Not Exist Qwerty")).to be_nil
        end

        it "should return nil for strings which are tags not part of the DICOM standard" do
          expect(LIBRARY.as_method("9999,QERT")).to be_nil
        end

      end

      describe "::as_tag" do

        it "should return the input value when that is a tag" do
          expect(LIBRARY.as_tag("0002,0000")).to eq("0002,0000")
        end

        it "should return the tag for strings which are names" do
          expect(LIBRARY.as_tag("File Meta Information Group Length")).to eq("0002,0000")
        end

        it "should return the tag for strings which are methods" do
          expect(LIBRARY.as_tag("file_meta_information_group_length")).to eq("0002,0000")
        end

        it "should return nil for strings which are method names corresponding to non-existant tags" do
          expect(LIBRARY.as_tag("this_method_does_not_exist_qwerty")).to be_nil
        end

        it "should return nil for strings which are names corresponding to non-existant tags" do
          expect(LIBRARY.as_tag("This Name Does Not Exist Qwerty")).to be_nil
        end

        it "should return nil for strings which non-existant tags" do
          expect(LIBRARY.as_tag("9999,QERT")).to be_nil
        end

      end

      describe "::as_name" do

        it "should return the input value when that is a name" do
          expect(LIBRARY.as_name("File Meta Information Group Length")).to eq("File Meta Information Group Length")
        end

        it "should return the name for strings which are method names" do
          expect(LIBRARY.as_name("file_meta_information_group_length")).to eq("File Meta Information Group Length")
        end

        it "should return the name for strings which are tags" do
          expect(LIBRARY.as_name("0002,0000")).to eq("File Meta Information Group Length")
        end

        it "should return nil for strings which are method names corresponding to non-existant names" do
          expect(LIBRARY.as_name("this_method_does_not_exist_qwerty")).to be_nil
        end

        it "should return nil for strings which are non-existant names" do
          expect(LIBRARY.as_name("This Name Does Not Exist Qwerty")).to be_nil
        end

        it "should return nil for strings which are tags corresponding to non-existant names" do
          expect(LIBRARY.as_name("9999,QERT")).to be_nil
        end

      end

    end


    describe String do

      describe "#to_element_method" do

        it "should return a method name 'three_d_stuff_and_with_some_weird_characters' for '3d Stuff & with some !? weird !!! characters'" do
          expect("3d Stuff & with some !? weird !!! characters".to_element_method).to eq(:three_d_stuff_and_with_some_weird_characters)
        end

        it "should return a method name 'three_d_something_its_nice' for '3d (something) it's NICE'" do
          expect("3d (something) it's NICE".to_element_method).to eq(:three_d_something_its_nice)
        end

        # Comment: How non-ascii characters in method names should be handled is something that may be up for debate.
        it "should return a method name with the non-ascii character preserved" do
          #"hello µValue it's STUPID".to_element_method.should == :hello_uvalue_its_stupid # (alternative spec)
          expect("hello µValue it's STUPID".to_element_method).to eq(:hello_µvalue_its_stupid)
        end

      end

      describe "#dicom_name?" do

        it "should return true if the string looks like a DICOM element name" do
          expect("This Looks Like A Name".dicom_name?).to be_truthy
        end

        it "should return false if the string doesnt look like a DICOM element name" do
          expect("this Doesnt Look like a name".dicom_name?).to be_falsey
        end

        it "should return false if the string looks like a DICOM method name" do
          expect("this_looks_like_a_method_name".dicom_name?).to be_falsey
        end

      end

      describe "#dicom_method?" do

        it "should return true if the string looks like a DICOM method name" do
          expect("this_looks_like_a_method_name".dicom_method?).to be_truthy
        end

        it "should return false if the string doesnt look like a DICOM method name" do
          expect("This_doesnt look_like a MethodName".dicom_method?).to be_falsey
        end

        it "should return false if the string looks like a DICOM element name" do
          expect("This Looks Like A Name".dicom_method?).to be_falsey
        end

      end

    end

  end

end