# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe DObject do

    before :each do
      DICOM.logger = Logger.new(STDOUT)
      DICOM.logger.level = Logger::FATAL
    end

    context "::new" do

      it "should create an empty DICOM object" do
        dcm = DObject.new
        dcm.class.should eql DObject
        dcm.count.should eql 0
      end

      it "should set the parent attribute as nil, as a DObject intance doesn't have a parent" do
        dcm = DObject.new
        dcm.parent.should be_nil
      end

      it "should set the read success attribute as nil when initializing an empty DICOM object" do
        dcm = DObject.new
        dcm.read?.should be_nil
      end

      it "should set the write success attribute as nil when initializing an empty DICOM object" do
        dcm = DObject.new
        dcm.written?.should be_nil
      end

      it "should store a Stream instance in the stream attribute" do
        dcm = DObject.new
        dcm.stream.class.should eql Stream
      end

      it "should use little endian as default string endianness for the Stream instance used in an empty DICOM object" do
        dcm = DObject.new
        dcm.stream.str_endian.should be_false
      end

    end


    context "::parse" do

      it "should successfully parse the encoded DICOM string" do
        str = File.open(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, "rb") { |f| f.read }
        dcm = DObject.parse(str)
        dcm.read?.should be_true
        dcm.children.length.should eql 85 # (This file is known to have 85 top level data elements)
      end

      it "should apply the specified transfer syntax to the DICOM object, when parsing a header-less DICOM binary string" do
        dcm = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
        syntax = dcm.transfer_syntax
        dcm.delete_group("0002")
        parts = dcm.encode_segments(16384)
        dcm_from_bin = DObject.parse(parts.join, :bin => true, :no_meta => true, :syntax => syntax)
        dcm_from_bin.transfer_syntax.should eql syntax
      end

      it "should fail to read this DICOM file when an incorrect transfer syntax option is supplied" do
        str = File.open(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, "rb") { |f| f.read }
        dcm = DObject.parse(str, :syntax => IMPLICIT_LITTLE_ENDIAN)
        dcm.read?.should be_false
      end

      it "should register one or more errors/warnings in the log when failing to successfully read a DICOM file" do
        DICOM.logger = mock("Logger")
        DICOM.logger.expects(:warn).at_least_once
        DICOM.logger.expects(:error).at_least_once
        str = File.open(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, "rb") { |f| f.read }
        dcm = DObject.parse(str, :syntax => IMPLICIT_LITTLE_ENDIAN)
      end

      it "should return the data elements that were successfully read before a failure occured (the file meta header elements in this case)" do
        str = File.open(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, "rb") { |f| f.read }
        dcm = DObject.parse(str, :syntax => IMPLICIT_LITTLE_ENDIAN)
        dcm.read?.should be_false
        dcm.children.length.should eql 8 # (Only its 8 meta header data elements should be read correctly)
      end

    end


    context "::read" do

      it "should successfully read this DICOM file" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        dcm.read?.should be_true
        dcm.children.length.should eql 85 # (This file is known to have 85 top level data elements)
      end

      it "should register an error when an invalid file is supplied" do
        DICOM.logger.expects(:error).at_least_once
        dcm = DObject.read("foo")
      end

      it "should fail gracefully when a small, non-dicom file is passed as an argument" do
        File.open(TMPDIR + "small_invalid.dcm", 'wb') {|f| f.write("fail"*20) }
        dcm = DObject.read(TMPDIR + "small_invalid.dcm")
        dcm.read?.should be_false
      end

      it "should fail gracefully when a tiny, non-dicom file is passed as an argument" do
        File.open(TMPDIR + "tiny_invalid.dcm", 'wb') {|f| f.write("fail") }
        dcm = DObject.read(TMPDIR + "tiny_invalid.dcm")
        dcm.read?.should be_false
      end

      it "should fail gracefully when a directory is passed as an argument" do
        dcm = DObject.read(TMPDIR)
        dcm.read?.should be_false
      end

    end


    describe "#==()" do

      it "should be true when comparing two instances having the same attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        (dcm1 == dcm2).should be_true
      end

      it "should be false when comparing two instances having different attribute values (different children)" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm2.add(Sequence.new("0008,0006"))
        (dcm1 == dcm2).should be_false
      end

      it "should be false when comparing against an instance of incompatible type" do
        dcm = DObject.new
        (dcm == 42).should be_false
      end

    end


    describe "#eql?" do

      it "should be true when comparing two instances having the same attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm1.eql?(dcm2).should be_true
      end

      it "should be false when comparing two instances having different attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm2.add(Sequence.new("0008,0006"))
        dcm1.eql?(dcm2).should be_false
      end

    end


    context "#encode_segments" do

      it "should raise ArgumentError when a non-integer argument is used" do
        dcm = DObject.new
        expect {dcm.encode_segments(3.5)}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when a ridiculously low integer argument is used" do
        dcm = DObject.new
        expect {dcm.encode_segments(8)}.to raise_error(ArgumentError)
      end

      it "should raise an error when this method is attempted called on an empty DICOM object" do
        dcm = DObject.new
        expect {dcm.encode_segments(512)}.to raise_error
      end

      it "should encode exactly the same binary string regardless of the max segment length chosen" do
        DICOM.logger.expects(:info).at_least_once
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        binaries = Array.new
        binaries << dcm.encode_segments(32768).join
        binaries << dcm.encode_segments(16384).join
        binaries << dcm.encode_segments(8192).join
        binaries << dcm.encode_segments(4096).join
        binaries << dcm.encode_segments(2048).join
        binaries << dcm.encode_segments(1024).join
        binaries.uniq.length.should eql 1
      end

      it "should should have its rejoined, segmented binary be successfully read to a DICOM object" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        binary = dcm.encode_segments(16384).join
        dcm_reloaded = DObject.parse(binary, :bin => true)
        dcm_reloaded.read?.should be_true
      end

    end


    describe "#hash" do

      it "should return the same Fixnum for two instances having the same attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm1.hash.should eql dcm2.hash
      end

      it "should return a different Fixnum for two instances having different attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm2.add(Sequence.new("0008,0006"))
        dcm1.hash.should_not eql dcm2.hash
      end

    end


    describe "#to_dcm" do

      it "should return itself" do
        dcm = DObject.new
        dcm.to_dcm.equal?(dcm).should be_true
      end

    end


    context "#transfer_syntax" do

      it "should return the default transfer syntax (Implicit, little endian) when the DICOM object has no transfer syntax tag" do
        dcm = DObject.new
        dcm.transfer_syntax.should eql IMPLICIT_LITTLE_ENDIAN
      end

      it "should return the value of the transfer syntax tag of the DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        dcm.transfer_syntax.should eql EXPLICIT_BIG_ENDIAN
      end

      it "should set the determined transfer syntax (Explicit Little Endian) when loading a DICOM file (lacking transfer syntax) using two passes" do
        dcm = DObject.read(DCM_EXPLICIT_NO_HEADER)
        dcm.transfer_syntax.should eql EXPLICIT_LITTLE_ENDIAN
      end

    end


    context "#transfer_syntax=()" do

      it "should change the transfer syntax of the empty DICOM object" do
        dcm = DObject.new
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        dcm.transfer_syntax.should eql EXPLICIT_BIG_ENDIAN
      end

      it "should change the transfer syntax of the DICOM object which has been read from file" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        dcm.transfer_syntax = IMPLICIT_LITTLE_ENDIAN
        dcm.transfer_syntax.should eql IMPLICIT_LITTLE_ENDIAN
      end

      it "should change the encoding of the data element's binary when switching endianness" do
        dcm = DObject.new
        dcm.add(Element.new("0018,1310", 500)) # This should give the binary string "\364\001"
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        dcm["0018,1310"].bin.should eql "\001\364"
      end

      it "should not change the encoding of any meta group data element's binaries when switching endianness" do
        dcm = DObject.new
        dcm.add(Element.new("0002,9999", 500, :vr => "US")) # This should give the binary string "\364\001"
        dcm.add(Element.new("0018,1310", 500))
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        dcm["0002,9999"].bin.should eql "\364\001"
      end

      it "should change the encoding of pixel data binary when switching endianness" do
        dcm = DObject.new
        dcm.add(Element.new("0018,1310", 500)) # This should give the binary string "\364\001"
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        dcm["0018,1310"].bin.should eql "\001\364"
      end

    end


    context "#read" do

      before :each do
        @file = DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2
      end

      it "should raise ArgumentError when a non-string argument is used" do
        dcm = DObject.read(@file)
        expect {dcm.read(33)}.to raise_error(ArgumentError)
      end

      it "should delete any old data elements when reading a new DICOM file into the DICOM object" do
        dcm = DObject.new
        dcm.add(Element.new("9999,9999", "test", :vr => "AE"))
        dcm.read(@file)
        dcm.exists?("9999,9999").should be_false
      end

    end


    # Writing a full DObject which has been read from file.
    context "#write" do

      before :each do
        @dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        @output = TMPDIR + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      end

      it "should raise ArgumentError when a non-string argument is used" do
        expect {@dcm.write(33)}.to raise_error(ArgumentError)
      end

      it "should set the written? attribute as true after successfully writing this DICOM object to file" do
        @dcm.write(@output)
        @dcm.written?.should be_true
      end

      it "should be able to successfully read the written DICOM file if it was written correctly" do
        @dcm.write(@output)
        dcm_reloaded = DObject.read(@output)
        dcm_reloaded.read?.should be_true
      end

      it "should create non-existing directories that are part of the file path, and write the file successfully" do
        path = TMPDIR + "create/these/directories/" + "test-directory-create.dcm"
        @dcm.write(path)
        @dcm.written?.should be_true
        File.exists?(path).should be_true
      end

    end


    # Writing a limited DObject created from scratch.
    context "#write" do

      before :each do
        @path = TMPDIR + "write.dcm"
        @dcm = DObject.new
        @dcm.add(Element.new("0008,0016", "1.2.34567"))
        @dcm.add(Element.new("0008,0018", "1.2.34567.89"))
      end

      it "should succeed in writing a limited DICOM object, created from scratch" do
        @dcm.write(@path)
        @dcm.written?.should be_true
        File.exists?(@path).should be_true
      end

      it "should add the File Meta Information Version to the File Meta Group, when it is undefined" do
        @dcm.write(@path)
        @dcm.exists?("0002,0001").should be_true
      end

      it "should use the SOP Class UID to create the Media Storage SOP Class UID of the File Meta Group when it is undefined" do
        @dcm.write(@path)
        @dcm.value("0002,0002").should eql @dcm.value("0008,0016")
      end

      it "should use the SOP Instance UID to create the Media Storage SOP Instance UID of the File Meta Group when it is undefined" do
        @dcm.write(@path)
        @dcm.value("0002,0003").should eql @dcm.value("0008,0018")
      end

      it "should add (the default) Transfer Syntax UID to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        @dcm.value("0002,0010").should eql IMPLICIT_LITTLE_ENDIAN
      end

      it "should add the Implementation Class UID to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        @dcm.value("0002,0012").should eql UID
      end

      it "should add the Implementation Version Name to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        @dcm.value("0002,0013").should eql NAME
      end

      it "should add the Source Application Entity Title to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        @dcm.value("0002,0016").should eql DICOM.source_app_title
      end

      it "should add a user-defined Source Application Entity Title to the File Meta Group when it is undefined (in the DObject)" do
        original_title = DICOM.source_app_title
        DICOM.source_app_title = "MY_TITLE"
        @dcm.write(@path)
        @dcm.value("0002,0016").should eql "MY_TITLE"
        DICOM.source_app_title = original_title
      end

      it "should not add the Implementation Class UID to the File Meta Group, when (it is undefined and) the Implementation Version Name is defined" do
        @dcm.add(Element.new("0002,0013", "SomeProgram"))
        @dcm.write(@path)
        @dcm.exists?("0002,0012").should be_false
      end

      it "should not add the Implementation Version Name to the File Meta Group, when (it is undefined and) the Implementation Class UID is defined" do
        @dcm.add(Element.new("0002,0012", "1.2.54321"))
        @dcm.write(@path)
        @dcm.exists?("0002,0013").should be_false
      end

    end


    # FIXME? Currently there is no specification for the format of the summary printout.
    #
    context "#summary" do

      it "should print the summary to the screen and return an array of information when called on a full DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        dcm.expects(:puts).at_least_once
        dcm.summary.should be_an(Array)
      end

      it "should print the summary to the screen and return an array of information when called on an empty DICOM object" do
        dcm = DObject.new
        dcm.expects(:puts).at_least_once
        dcm.summary.should be_an(Array)
      end

    end


    context "#print_all" do

      it "should successfully print information to the screen" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        dcm.expects(:puts).at_least_once
        dcm.print_all
      end

      it "should successfully print information to the screen when called on an empty DICOM object" do
        dcm = DObject.new
        dcm.expects(:puts).at_least_once
        dcm.print_all
      end

    end

  end

end
