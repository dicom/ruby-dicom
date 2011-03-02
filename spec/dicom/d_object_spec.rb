# coding: UTF-8

require 'spec_helper'


module DICOM

  describe DObject, "#new" do
    
    it "should raise ArgumentError when creation is attempted with an argument that is not a string (or nil)" do
      expect {DObject.new(42)}.to raise_error(ArgumentError)
    end
    
    it "should raise ArgumentError when creation is attempted with an argument that is not a string (or nil)" do
      expect {DObject.new(true)}.to raise_error(ArgumentError)
    end
    
    it "should initialize with an empty errors array" do
      obj = DObject.new(nil)
      obj.errors.class.should eql Array
      obj.errors.length.should eql 0
    end
    
    it "should set the parent attribute as nil, as a DObject intance doesn't have a parent" do
      obj = DObject.new(nil)
      obj.parent.should be_nil
    end
    
    it "should set the read success attribute as nil when initializing an empty DICOM object" do
      obj = DObject.new(nil)
      obj.read_success.should be_nil
    end
    
    it "should set the write success attribute as nil when initializing an empty DICOM object" do
      obj = DObject.new(nil)
      obj.write_success.should be_nil
    end
    
    it "should store a Stream instance in the stream attribute" do
      obj = DObject.new(nil)
      obj.stream.class.should eql Stream
    end
    
    it "should use little endian as default string endianness for the Stream instance used in an empty DICOM object" do
      obj = DObject.new(nil)
      obj.stream.str_endian.should be_false
    end
    
  end

end