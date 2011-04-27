# coding: UTF-8

require 'spec_helper'
module DICOM
  describe DICOM do
    
    context "Dicom Extensions" do
    
      context DObject do
    
        before(:each) { @dicom = DObject.new(Dir.pwd+'/spec/support/sample_explicit_mr_jpeg-lossy_mono2.dcm') }
    
        it 'has an elements Array' do
          @dicom.elements.should be_an Array
        end
    
        it "has a #file_meta_information_group_length" do
          @dicom.file_meta_information_group_length.value.should_not be_nil
        end
    
        it { @dicom.should_not respond_to :any_method_name_that_should_not_work }
    
        it "has a number of frames" do
          @dicom.num_frames.should be_>=1
        end
    
        it "queries the dicom object for the existence of a tag using <methodized-name>?" do
           @dicom.sop_instance_uid?.should be_true
        end
    
        it "queries the dicom object for the existence of a tag using <methodized-name>? returning false if it doesnt exist" do
          @dicom.sop_instance_uid = nil
           @dicom.sop_instance_uid?.should be_false
        end
    
        it "queries the dicom object for the existence of a tag using <methodized-name>? returning true if it exists" do
          @dicom.sop_instance_uid = '1.2.3.4.5.6'
           @dicom.sop_instance_uid?.should be_true
        end
    
        it "sets the sop_instance_uid to '1.2.3.4.5'" do
          @dicom.sop_instance_uid = '1.2.3.4.5'
          @dicom.sop_instance_uid.value.should eql '1.2.3.4.5'
        end
    
        it "anonymizes the sop_instance_uid" do
          @dicom.anonymize(:sop_instance_uid => 'anonymized')
          @dicom.sop_instance_uid.value.should eql 'anonymized'
        end
    
        it "deletes the sop_instance_uid" do
          @dicom.sop_instance_uid = nil
          @dicom.sop_instance_uid?.should be_false
        end
    
        it "sets file_meta_information_group_length from a hash value" do
          hash = { :ahash => 4567, :should => 'work' }
          @dicom.file_meta_information_group_length = hash
          @dicom.file_meta_information_group_length.value.should == hash.to_s.to_i
        end
    
        it "sets file_meta_information_group_length from an array value" do
          arr = [1,2,3,4,5,"string"]
          @dicom.file_meta_information_group_length = arr
          @dicom.file_meta_information_group_length.value.should == arr.to_s.to_i
        end
    
        it "sets file_meta_information_group_length from a float value" do
          float = 1267.38991
          @dicom.file_meta_information_group_length = float
          @dicom.file_meta_information_group_length.value.should == float.to_s.to_i
        end
    
        it "sets file_meta_information_group_length from a fixnum value" do
          fixnum = 12345
          @dicom.file_meta_information_group_length = fixnum
          @dicom.file_meta_information_group_length.value.should == fixnum.to_s.to_i
        end
    
        it "sets file_meta_information_group_length from an object value" do
          object = Object.new
          @dicom.file_meta_information_group_length = object
          @dicom.file_meta_information_group_length.value.should == object.to_s.to_i
        end
    
        it "sets file_meta_information_group_length from a string value" do
          string = 'this is a string value'
          @dicom.file_meta_information_group_length = string
          @dicom.file_meta_information_group_length.value.should == string.to_s.to_i
        end
    
        it "sets sop_instance_uid from a hash value" do
          hash = { :ahash => 4567, :should => 'work' }
          @dicom.sop_instance_uid = hash
          @dicom.sop_instance_uid.value.should == hash.to_s
        end
    
        it "sets sop_instance_uid from an array value" do
          arr = [1,2,3,4,5,"string"]
          @dicom.sop_instance_uid = arr
          @dicom.sop_instance_uid.value.should == arr.to_s
        end
    
        it "sets sop_instance_uid from a float value" do
          float = 1267.38991
          @dicom.sop_instance_uid = float
          @dicom.sop_instance_uid.value.should == float.to_s
        end
    
        it "sets sop_instance_uid from a fixnum value" do
          fixnum = 12345
          @dicom.sop_instance_uid = fixnum
          @dicom.sop_instance_uid.value.should == fixnum.to_s
        end
    
        it "sets sop_instance_uid from an object value" do
          object = Object.new
          @dicom.sop_instance_uid = object
          @dicom.sop_instance_uid.value.should == object.to_s
        end
    
        it "sets sop_instance_uid from a string value" do
          string = 'this is a string value'
          @dicom.sop_instance_uid = string
          @dicom.sop_instance_uid.value.should == string.to_s
        end
    
        it "sets examined_body_thickness from a hash value" do
          hash = { :ahash => 4567, :should => 'work' }
          @dicom.examined_body_thickness = hash
          @dicom.examined_body_thickness.value.should == hash.to_s.to_f
        end
    
        it "sets examined_body_thickness from an array value" do
          arr = [1,2,3,4,5,"string"]
          @dicom.examined_body_thickness = arr
          @dicom.examined_body_thickness.value.should == arr.to_s.to_f
        end
    
        it "sets examined_body_thickness from a float value" do
          float = 1267.38991
          @dicom.examined_body_thickness = float
          @dicom.examined_body_thickness.value.should == float.to_s.to_f
        end
    
        it "sets examined_body_thickness from a fixnum value" do
          fixnum = 12345
          @dicom.examined_body_thickness = fixnum
          @dicom.examined_body_thickness.value.should == fixnum.to_s.to_f
        end
    
        it "sets examined_body_thickness from an object value" do
          object = Object.new
          @dicom.examined_body_thickness = object
          @dicom.examined_body_thickness.value.should == object.to_s.to_f
        end
    
        it "sets examined_body_thickness from a string value" do
          string = 'this is a string value'
          @dicom.examined_body_thickness = string
          @dicom.examined_body_thickness.value.should == string.to_s.to_f
        end
    
        it "converts to hash with fields as dicom field names" do
          DICOM.json_use_names
          @dicom.to_hash.key?('File Meta Information Group Length').should be_true
        end
    
        it "converts to hash with fields as dicom method symbols" do
          DICOM.json_use_method_names
          @dicom.to_hash.key?(:file_meta_information_group_length).should be_true
        end
    
        it "converts to hash with fields as dicom tags" do
          DICOM.json_use_tags
          @dicom.to_hash.key?('0002,0000').should be_true
        end
    
      end
    
    end
    
    context DLibrary do
    
      context LIBRARY.method(:get_tag) do
    
        it "returns the tag corresponding to a name" do
          LIBRARY.get_tag('File Meta Information Group Length').should == '0002,0000'
        end
    
        it "returns nil if the tag does not exist for the given name" do
          LIBRARY.get_tag('This Name Does Not Exist Qwerty').should be_nil
        end
    
      end
    
    
      context LIBRARY.method(:as_method) do
    
        it "returns the input value as a symbol when that is a method name" do
          LIBRARY.as_method('file_meta_information_group_length').should be :file_meta_information_group_length
        end
    
        it "returns the method name as a symbol for strings which are names" do
          LIBRARY.as_method('File Meta Information Group Length').should be :file_meta_information_group_length
        end
    
        it "returns the method name as a symbol for strings which are tags" do
          LIBRARY.as_method('0002,0000').should be :file_meta_information_group_length
        end
    
        it "returns nil for strings which are non-existant methods" do
          LIBRARY.as_method('this_method_does_not_exist_qwerty').should be_nil
        end
    
        it "returns nil for strings which are names of non-existant methods" do
          LIBRARY.as_method('This Name Does Not Exist Qwerty').should be_nil
        end
    
        it "returns nil for strings which are tags not part of the dicom standard" do
          LIBRARY.as_method('9999,QERT').should be_nil
        end
    
      end
    
      context LIBRARY.method(:as_tag) do
    
        it "returns the input value when that is a tag" do
          LIBRARY.as_tag('0002,0000').should == '0002,0000'
        end
    
        it "returns the tag for strings which are names" do
          LIBRARY.as_tag('File Meta Information Group Length').should == '0002,0000'
        end
    
        it "returns the tag for strings which are methods" do
          LIBRARY.as_tag('file_meta_information_group_length').should == '0002,0000'
        end
    
        it "returns nil for strings which are method names corresponding to non-existant tags" do
          LIBRARY.as_tag('this_method_does_not_exist_qwerty').should be_nil
        end
    
        it "returns nil for strings which are names corresponding to non-existant tags" do
          LIBRARY.as_tag('This Name Does Not Exist Qwerty').should be_nil
        end
    
        it "returns nil for strings which non-existant tags" do
          LIBRARY.as_tag('9999,QERT').should be_nil
        end
    
      end
    
      context LIBRARY.method(:as_name) do
    
        it "returns the input value when that is a name" do
          LIBRARY.as_name('File Meta Information Group Length').should == 'File Meta Information Group Length'
        end
    
        it "returns the name for strings which are method names" do
          LIBRARY.as_name('file_meta_information_group_length').should == 'File Meta Information Group Length'
        end
    
        it "returns the name for strings which are tags" do
          LIBRARY.as_name('0002,0000').should == 'File Meta Information Group Length'
        end
    
        it "returns nil for strings which are method names corresponding to non-existant names" do
          LIBRARY.as_name('this_method_does_not_exist_qwerty').should be_nil
        end
    
        it "returns nil for strings which are non-existant names" do
          LIBRARY.as_name('This Name Does Not Exist Qwerty').should be_nil
        end
    
        it "returns nil for strings which are tags corresponding to non-existant names" do
          LIBRARY.as_name('9999,QERT').should be_nil
        end
    
      end
    
      context String, 'extensions' do
    
        context "".method(:dicom_methodize) do
    
          it "returns a method name 'three_d_stuff_and_with_some_weird_characters' for '3d Stuff & with some !? weird !!! characters'" do
            '3d Stuff & with some !? weird !!! characters'.dicom_methodize.should == 'three_d_stuff_and_with_some_weird_characters'
          end
    
          it "returns a method name 'three_d_something_its_nice' for '3d (something) it's NICE'" do
            "3d (something) it's NICE".dicom_methodize.should == 'three_d_something_its_nice'
          end
    
          it "returns a method name 'hello_uvalue_its_stupid' for 'hello µValue it's STUPID'" do
            "hello µValue it's STUPID".dicom_methodize.should == 'hello_uvalue_its_stupid'
          end
    
        end
    
        context "".method(:dicom_name?) do
          it "returns true if string looks like a Dicom element name" do
            'This Looks Like A Name'.dicom_name?.should be_true
          end
    
          it "returns false if string doesnt look like a Dicom element name" do
            'this Doesnt Look like a name'.dicom_name?.should be_false
          end
        end
    
        context "".method(:dicom_method?) do
          it "returns true if string looks like a Dicom method name" do
            'this_looks_like_a_method_name'.dicom_method?.should be_true
          end
    
          it "returns false if string doesnt look like a Dicom method name" do
            'This_doesnt look_like a MethodName'.dicom_method?.should be_false
          end
        end
    
      end
    
    end
    
  end
  
end