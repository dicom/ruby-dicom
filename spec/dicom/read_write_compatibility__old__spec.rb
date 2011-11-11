# encoding: ASCII-8BIT

# Compatibility specification. Ruby DICOM should be able to read and write all these sample DICOM files successfully.

# NB: The spec examples in this file uses the old (deprecated) way of loading DICOM objects from files,
# and this file will be removed when this particular featre is removed from ruby-dicom!!

require 'spec_helper'


module DICOM

  describe DObject do

    before :each do
      DICOM.logger = Logger.new(STDOUT)
      DICOM.logger.level = Logger::FATAL
    end

    describe "::new(nil)" do

      it "should create an empty DICOM object" do
        obj = DObject.new(nil)
        obj.class.should eql DObject
        obj.count.should eql 0
      end

    end


    describe "::new(bin)" do

      it "should successfully read this DICOM file, when it is supplied as a binary string instead of a file name" do
        str = File.open(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, "rb") { |f| f.read }
        obj = DObject.new(str, :bin => true)
        obj.read?.should be_true
        obj.children.length.should eql 85 # (This file is known to have 85 top level data elements)
      end

      it "should apply the specified transfer syntax to the DICOM object, when passing a syntax-less DICOM binary string" do
        obj = DObject.new(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
        syntax = obj.transfer_syntax
        obj.remove_group("0002")
        parts = obj.encode_segments(16384)
        obj_from_bin = DObject.new(parts.join, :bin => true, :syntax => syntax)
        obj_from_bin.transfer_syntax.should eql syntax
      end

    end


    describe "::new(file)" do

      it "should raise ArgumentError when creation is attempted with an argument that is not a string (or nil)" do
        expect {DObject.new(42)}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when creation is attempted with an argument that is not a string (or nil)" do
        expect {DObject.new(true)}.to raise_error(ArgumentError)
      end

      it "should set the parent attribute as nil, as a DObject intance doesn't have a parent" do
        obj = DObject.new(nil)
        obj.parent.should be_nil
      end

      it "should set the read success attribute as nil when initializing an empty DICOM object" do
        obj = DObject.new(nil)
        obj.read?.should be_nil
      end

      it "should set the write success attribute as nil when initializing an empty DICOM object" do
        obj = DObject.new(nil)
        obj.written?.should be_nil
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
        obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        obj.read?.should be_true
        obj.children.length.should eql 85 # (This file is known to have 85 top level data elements)
      end

      it "should fail to read this DICOM file when an incorrect transfer syntax option is supplied" do
        obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :syntax => IMPLICIT_LITTLE_ENDIAN)
        obj.read?.should be_false
      end

      it "should register one or more errors/warnings in the log when failing to successfully read a DICOM file" do
        DICOM.logger = mock("Logger")
        DICOM.logger.expects(:warn).at_least_once
        DICOM.logger.expects(:error).at_least_once
        obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :syntax => IMPLICIT_LITTLE_ENDIAN)
      end

      it "should return the data elements that were successfully read before a failure occured (the file meta header elements in this case)" do
        obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :syntax => IMPLICIT_LITTLE_ENDIAN)
        obj.read?.should be_false
        obj.children.length.should eql 8 # (Only its 8 meta header data elements should be read correctly)
      end

      it "should register an error when an invalid file is supplied" do
        DICOM.logger.expects(:error).at_least_once
        obj = DObject.new("foo")
      end

      it "should fail gracefully when a small, non-dicom file is passed as an argument" do
        File.open(TMPDIR + "small_invalid.dcm", 'wb') {|f| f.write("fail"*20) }
        obj = DObject.new(TMPDIR + "small_invalid.dcm")
        obj.read?.should be_false
      end

      it "should fail gracefully when a tiny, non-dicom file is passed as an argument" do
        File.open(TMPDIR + "tiny_invalid.dcm", 'wb') {|f| f.write("fail") }
        obj = DObject.new(TMPDIR + "tiny_invalid.dcm")
        obj.read?.should be_false
      end

      it "should fail gracefully when a directory is passed as an argument" do
        obj = DObject.new(TMPDIR)
        obj.read?.should be_false
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2)
        obj.read?.should be_true
        obj.count.should eql 83
        obj.count_all.should eql 83
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        obj.read?.should be_true
        obj.count.should eql 85
        obj.count_all.should eql 85
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        obj.read?.should be_true
        obj.count.should eql 44
        obj.count_all.should eql 44
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL)
        obj.read?.should be_true
        obj.count.should eql 33
        obj.count_all.should eql 33
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON)
        obj.read?.should be_true
        obj.count.should eql 152
        obj.count_all.should eql 177
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_RTDOSE_16BIT_MONO2_3D_VOLUME)
        obj.read?.should be_true
        obj.count.should eql 85
        obj.count_all.should eql 139
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        obj.read?.should be_true
        obj.count.should eql 97
        obj.count_all.should eql 123
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME)
        obj.read?.should be_true
        obj.count.should eql 45
        obj.count_all.should eql 56
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_MR_RLE_MONO2)
        obj.read?.should be_true
        obj.count.should eql 104
        obj.count_all.should eql 130
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
        obj.read?.should be_true
        obj.count.should eql 78
        obj.count_all.should eql 80
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME)
        obj.read?.should be_true
        obj.count.should eql 55
        obj.count_all.should eql 64
      end

      it "should parse this DICOM file and build a valid DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_NO_HEADER)
        obj.read?.should be_true
        obj.count.should eql 90
        obj.count_all.should eql 116
      end

    end


    context "#encode_segments" do

      it "should should have its rejoined, segmented binary be successfully read to a DICOM object" do
        obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        binary = obj.encode_segments(16384).join
        obj_reloaded = DObject.new(binary, :bin => true)
        obj_reloaded.read?.should be_true
      end

    end


    context "#transfer_syntax" do

      it "should return the default transfer syntax (Implicit, little endian) when the DICOM object has no transfer syntax tag" do
        obj = DObject.new(nil)
        obj.transfer_syntax.should eql IMPLICIT_LITTLE_ENDIAN
      end

      it "should return the value of the transfer syntax tag of the DICOM object" do
        obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        obj.transfer_syntax.should eql EXPLICIT_BIG_ENDIAN
      end

      it "should set the determined transfer syntax (Explicit Little Endian) when loading a DICOM file (lacking transfer syntax) using two passes" do
        obj = DObject.new(DCM_EXPLICIT_NO_HEADER)
        obj.transfer_syntax.should eql EXPLICIT_LITTLE_ENDIAN
      end

    end

  end

end