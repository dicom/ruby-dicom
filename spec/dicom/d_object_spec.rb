# encoding: ASCII-8BIT

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
      obj = DObject.new(nil, :verbose => false)
      obj.errors.class.should eql Array
      obj.errors.length.should eql 0
    end

    it "should set the parent attribute as nil, as a DObject intance doesn't have a parent" do
      obj = DObject.new(nil, :verbose => false)
      obj.parent.should be_nil
    end

    it "should set the read success attribute as nil when initializing an empty DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.read?.should be_nil
    end

    it "should set the write success attribute as nil when initializing an empty DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.written?.should be_nil
    end

    it "should store a Stream instance in the stream attribute" do
      obj = DObject.new(nil, :verbose => false)
      obj.stream.class.should eql Stream
    end

    it "should use little endian as default string endianness for the Stream instance used in an empty DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.stream.str_endian.should be_false
    end

    it "should successfully read this DICOM file" do
      obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.read?.should be_true
      obj.children.length.should eql 85 # (This file is known to have 85 top level data elements)
    end

    it "should successfully read this DICOM file, when it is supplied as a binary string instead of a file name" do
      file = File.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, "rb")
      str = file.read
      file.close
      obj = DObject.new(str, :bin => true, :verbose => false)
      obj.read?.should be_true
      obj.children.length.should eql 85 # (This file is known to have 85 top level data elements)
    end

    it "should fail to read this DICOM file when an incorrect transfer syntax option is supplied" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :syntax => IMPLICIT_LITTLE_ENDIAN, :verbose => false)
      obj.read?.should be_false
    end

    it "should register one or more errors/messages in the errors array when failing to successfully read a DICOM file" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :syntax => IMPLICIT_LITTLE_ENDIAN, :verbose => false)
      obj.errors.length.should be > 0
    end

    it "should return the data elements that were successfully read before a failure occured (the file meta header elements in this case)" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :syntax => IMPLICIT_LITTLE_ENDIAN, :verbose => false)
      obj.read?.should be_false
      obj.children.length.should eql 8 # (Only its 8 meta header data elements should be read correctly)
    end

    it "should register an error when an invalid file is supplied" do
      obj = DObject.new("foo", :verbose => false)
      obj.errors.length.should be > 0
    end

    it "should print the error/warning message(s) to $stdout in verbose (default) mode" do
      obj = DObject.new(nil)
      obj.expects(:puts).at_least_once
      obj.read("foo")
    end

    it "should not print the error/warning message(s) to $stdout when non-verbose mode has been set" do
      obj = DObject.new(nil, :verbose => false)
      obj.expects(:puts).never
      obj.read("foo")
    end

    it "should fail gracefully when a small, non-dicom file is passed as an argument" do
      File.open(TMPDIR + "small_invalid.dcm", 'wb') {|f| f.write("fail"*20) }
      obj = DObject.new(TMPDIR + "small_invalid.dcm", :verbose => false)
      obj.read?.should be_false
    end

    it "should fail gracefully when a tiny, non-dicom file is passed as an argument" do
      File.open(TMPDIR + "tiny_invalid.dcm", 'wb') {|f| f.write("fail") }
      obj = DObject.new(TMPDIR + "tiny_invalid.dcm", :verbose => false)
      obj.read?.should be_false
    end

    it "should fail gracefully when a directory is passed as an argument" do
      obj = DObject.new(TMPDIR, :verbose => false)
      obj.read?.should be_false
    end

    it "should apply the specified transfer syntax to the DICOM object, when passing a syntax-less DICOM binary string" do
      obj = DObject.new(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2, :verbose => false)
      syntax = obj.transfer_syntax
      obj.remove_group("0002")
      parts = obj.encode_segments(16384)
      obj_from_bin = DObject.new(parts.join, :verbose => false, :bin => true, :syntax => syntax)
      obj_from_bin.transfer_syntax.should eql syntax
    end

  end


  describe DObject, "#encode_segments" do

    it "should raise ArgumentError when a non-integer argument is used" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.encode_segments(3.5)}.to raise_error(ArgumentError)
    end

    it "should raise ArgumentError when a ridiculously low integer argument is used" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.encode_segments(8)}.to raise_error(ArgumentError)
    end

    it "should raise an error when this method is attempted called on an empty DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.encode_segments(512)}.to raise_error
    end

    it "should encode exactly the same binary string regardless of the max segment length chosen" do
      obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
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
      obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      binary = obj.encode_segments(16384).join
      obj_reloaded = DObject.new(binary, :bin => true, :verbose => false)
      obj_reloaded.read?.should be_true
    end

  end


  describe DObject, "#transfer_syntax" do

    it "should return the default transfer syntax (Implicit, little endian) when the DICOM object has no transfer syntax tag" do
      obj = DObject.new(nil, :verbose => false)
      obj.transfer_syntax.should eql IMPLICIT_LITTLE_ENDIAN
    end

    it "should return the value of the transfer syntax tag of the DICOM object" do
      obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG, :verbose => false)
      obj.transfer_syntax.should eql EXPLICIT_BIG_ENDIAN
    end

  end


  describe DObject, "#transfer_syntax=()" do

    it "should change the transfer syntax of the empty DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
      obj.transfer_syntax.should eql EXPLICIT_BIG_ENDIAN
    end

    it "should change the transfer syntax of the DICOM object which has been read from file" do
      obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG, :verbose => false)
      obj.transfer_syntax = IMPLICIT_LITTLE_ENDIAN
      obj.transfer_syntax.should eql IMPLICIT_LITTLE_ENDIAN
    end

    it "should change the encoding of the data element's binary when switching endianness" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0018,1310", 500)) # This should give the binary string "\364\001"
      obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
      obj["0018,1310"].bin.should eql "\001\364"
    end

    it "should not change the encoding of any meta group data element's binaries when switching endianness" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0002,9999", 500, :vr => "US")) # This should give the binary string "\364\001"
      obj.add(Element.new("0018,1310", 500))
      obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
      obj["0002,9999"].bin.should eql "\364\001"
    end

    it "should change the encoding of pixel data binary when switching endianness" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0018,1310", 500)) # This should give the binary string "\364\001"
      obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
      obj["0018,1310"].bin.should eql "\001\364"
    end

  end


  describe DObject, "#read" do

    before :each do
      @file = DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2
    end

    it "should raise ArgumentError when a non-string argument is used" do
      obj = DObject.new(@file, :verbose => false)
      expect {obj.read(33)}.to raise_error(ArgumentError)
    end

    it "should remove any old data elements when reading a new DICOM file into the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("9999,9999", "test", :vr => "AE"))
      obj.read(@file, :verbose => false)
      obj.exists?("9999,9999").should be_false
    end

  end


  # Writing a full DObject read from file.
  describe DObject, "#write" do

    before :each do
      @obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      @output = TMPDIR + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
    end

    it "should raise ArgumentError when a non-string argument is used" do
      expect {@obj.write(33)}.to raise_error(ArgumentError)
    end

    it "should set the written? attribute as true after successfully writing this DICOM object to file" do
      @obj.write(@output)
      @obj.written?.should be_true
    end

    it "should be able to successfully read the written DICOM file if it was written correctly" do
      @obj.write(@output)
      obj_reloaded = DObject.new(@output, :verbose => false)
      obj_reloaded.read?.should be_true
    end

    it "should create non-existing directories that are part of the file path, and write the file successfully" do
      path = TMPDIR + "create/these/directories/" + "test-directory-create.dcm"
      @obj.write(path)
      @obj.written?.should be_true
      File.exists?(path).should be_true
    end

  end


  # Writing a limited DObject created from scratch.
  describe DObject, "#write" do

    before :each do
      @path = TMPDIR + "write.dcm"
      @obj = DObject.new(nil, :verbose => false)
      @obj.add(Element.new("0008,0016", "1.2.34567"))
      @obj.add(Element.new("0008,0018", "1.2.34567.89"))
    end

    it "should succeed in writing a limited DICOM object, created from scratch" do
      @obj.write(@path)
      @obj.written?.should be_true
      File.exists?(@path).should be_true
    end

    it "should add the File Meta Information Version to the File Meta Group, when it is undefined" do
      @obj.write(@path)
      @obj.exists?("0002,0001").should be_true
    end

    it "should use the SOP Class UID to create the Media Storage SOP Class UID of the File Meta Group when it is undefined" do
      @obj.write(@path)
      @obj.value("0002,0002").should eql @obj.value("0008,0016")
    end

    it "should use the SOP Instance UID to create the Media Storage SOP Instance UID of the File Meta Group when it is undefined" do
      @obj.write(@path)
      @obj.value("0002,0003").should eql @obj.value("0008,0018")
    end

    it "should add (the default) Transfer Syntax UID to the File Meta Group when it is undefined" do
      @obj.write(@path)
      @obj.value("0002,0010").should eql IMPLICIT_LITTLE_ENDIAN
    end

    it "should add the Implementation Class UID to the File Meta Group when it is undefined" do
      @obj.write(@path)
      @obj.value("0002,0012").should eql UID
    end

    it "should add the Implementation Version Name to the File Meta Group when it is undefined" do
      @obj.write(@path)
      @obj.value("0002,0013").should eql NAME
    end

    it "should add the Source Application Entity Title to the File Meta Group when it is undefined" do
      @obj.write(@path)
      @obj.value("0002,0016").should eql DICOM.source_app_title
    end

    it "should add a user-defined Source Application Entity Title to the File Meta Group when it is undefined (in the DObject)" do
      original_title = DICOM.source_app_title
      DICOM.source_app_title = "MY_TITLE"
      @obj.write(@path)
      @obj.value("0002,0016").should eql "MY_TITLE"
      DICOM.source_app_title = original_title
    end

    it "should not add the Implementation Class UID to the File Meta Group, when (it is undefined and) the Implementation Version Name is defined" do
      @obj.add(Element.new("0002,0013", "SomeProgram"))
      @obj.write(@path)
      @obj.exists?("0002,0012").should be_false
    end

    it "should not add the Implementation Version Name to the File Meta Group, when (it is undefined and) the Implementation Class UID is defined" do
      @obj.add(Element.new("0002,0012", "1.2.54321"))
      @obj.write(@path)
      @obj.exists?("0002,0013").should be_false
    end

  end


    # FIXME? Currently there is no specification for the format of the summary printout.
    #
  describe DObject, "#summary" do

    it "should print the summary to the screen and return an array of information when called on a full DICOM object" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj.expects(:puts).at_least_once
      obj.summary.should be_an(Array)
    end

    it "should print the summary to the screen and return an array of information when called on an empty DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.expects(:puts).at_least_once
      obj.summary.should be_an(Array)
    end

  end


  describe DObject, "#print_all" do

    it "should successfully print information to the screen" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj.expects(:puts).at_least_once
      obj.print_all
    end

    it "should successfully print information to the screen when called on an empty DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.expects(:puts).at_least_once
      obj.print_all
    end

  end

end