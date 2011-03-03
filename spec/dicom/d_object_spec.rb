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
    
    it "should successfully read this DICOM file" do
      obj = DObject.new(Dir.pwd+'/spec/support/sample_no-header_implicit_mr_16bit_mono2.dcm', :verbose => false)
      obj.read_success.should be_true
    end
    
  end
  
  
  describe DObject, "#encode_segments" do
    
    it "should raise ArgumentError when a non-integer argument is used" do
      obj = DObject.new(nil)
      expect {obj.encode_segments(3.5)}.to raise_error(ArgumentError)
    end
    
    it "should raise ArgumentError when a ridiculously low integer argument is used" do
      obj = DObject.new(nil)
      expect {obj.encode_segments(8)}.to raise_error(ArgumentError)
    end
    
    it "should raise an error when this method is attempted called on an empty DICOM object" do
      obj = DObject.new(nil)
      expect {obj.encode_segments(512)}.to raise_error
    end
    
    it "should encode exactly the same binary string regardless of the max segment length chosen" do
      obj = DObject.new(Dir.pwd+'/spec/support/sample_no-header_implicit_mr_16bit_mono2.dcm', :verbose => false)
      binaries = Array.new
      binaries << obj.encode_segments(32768).join
      binaries << obj.encode_segments(16384).join
      binaries << obj.encode_segments(8192).join
      binaries << obj.encode_segments(4096).join
      binaries << obj.encode_segments(2048).join
      binaries << obj.encode_segments(1024).join
      binaries.uniq.length.should eql 1
    end
    
    it "should should have its rejoined, segmented binary be successfully read to a DICOM object" do
      obj = DObject.new(Dir.pwd+'/spec/support/sample_no-header_implicit_mr_16bit_mono2.dcm', :verbose => false)
      binary = obj.encode_segments(16384).join
      obj_reloaded = DObject.new(binary, :bin => true, :verbose => false)
      obj_reloaded.read_success.should be_true
    end
    
  end

end