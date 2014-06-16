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
        expect(dcm.class).to eql DObject
        expect(dcm.count).to eql 0
      end

      it "should set the parent attribute as nil, as a DObject intance doesn't have a parent" do
        dcm = DObject.new
        expect(dcm.parent).to be_nil
      end

      it "should set the read success attribute as nil when initializing an empty DICOM object" do
        dcm = DObject.new
        expect(dcm.read?).to be_nil
      end

      it "should set the write success attribute as nil when initializing an empty DICOM object" do
        dcm = DObject.new
        expect(dcm.written?).to be_nil
      end

      it "should set the source attribute as nil when initializing an empty DICOM object" do
        dcm = DObject.new
        expect(dcm.source).to be_nil
      end

      it "should set the :was_dcm_on_input attribute as false when initializing an empty DICOM object" do
        dcm = DObject.new
        expect(dcm.was_dcm_on_input).to be_falsey
      end

      it "should store a Stream instance in the stream attribute" do
        dcm = DObject.new
        expect(dcm.stream.class).to eql Stream
      end

      it "should use little endian as default string endianness for the Stream instance used in an empty DICOM object" do
        dcm = DObject.new
        expect(dcm.stream.str_endian).to be_falsey
      end

    end


    context "::parse" do

      it "should successfully parse the encoded DICOM string" do
        str = File.open(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, 'rb') { |f| f.read }
        dcm = DObject.parse(str)
        expect(dcm.read?).to be_truthy
        expect(dcm.children.length).to eql 85 # (This file is known to have 85 top level data elements)
      end

      it "should apply the specified transfer syntax to the DICOM object, when parsing a header-less DICOM binary string" do
        dcm = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
        syntax = dcm.transfer_syntax
        dcm.delete_group('0002')
        parts = dcm.encode_segments(16384)
        dcm_from_bin = DObject.parse(parts.join, :bin => true, :no_meta => true, :syntax => syntax)
        expect(dcm_from_bin.transfer_syntax).to eql syntax
      end

      it "should fail to read this DICOM file when an incorrect transfer syntax option is supplied" do
        str = File.open(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, 'rb') { |f| f.read }
        dcm = DObject.parse(str, :syntax => IMPLICIT_LITTLE_ENDIAN)
        expect(dcm.read?).to be_falsey
      end

      it "should register one or more errors/warnings/debugs in the log when failing to successfully parse a DICOM string" do
        DICOM.logger = mock('Logger')
        DICOM.logger.expects(:warn).at_least_once
        DICOM.logger.expects(:debug).at_least_once
        DICOM.logger.expects(:error).at_least_once
        str = File.open(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, 'rb') { |f| f.read }
        dcm = DObject.parse(str, :syntax => IMPLICIT_LITTLE_ENDIAN)
      end

      it "should return the data elements that were successfully read before a failure occured (the file meta header elements in this case)" do
        str = File.open(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, 'rb') { |f| f.read }
        dcm = DObject.parse(str, :syntax => IMPLICIT_LITTLE_ENDIAN)
        expect(dcm.read?).to be_falsey
        expect(dcm.children.length).to eql 8 # (Only its 8 meta header data elements should be read correctly)
      end

      it "should set :str as the 'source' attribute" do
        str = File.open(DCM_ISO8859_1, 'rb') { |f| f.read }
        dcm = DObject.parse(str, :syntax => EXPLICIT_LITTLE_ENDIAN)
        expect(dcm.source).to eql :str
      end

    end


    context "::read" do

      it "should successfully read this DICOM file" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.read?).to be_truthy
        expect(dcm.children.length).to eql 85 # (This file is known to have 85 top level data elements)
      end

      it "should register an error when an invalid file is supplied" do
        DICOM.logger.expects(:error).at_least_once
        dcm = DObject.read('foo')
      end

      it "should fail gracefully when a small, non-dicom file is passed as an argument" do
        File.open(TMPDIR + 'small_invalid.dcm', 'wb') {|f| f.write('fail'*20) }
        dcm = DObject.read(TMPDIR + 'small_invalid.dcm')
        expect(dcm.read?).to be_falsey
      end

      it "should fail gracefully when a tiny, non-dicom file is passed as an argument" do
        File.open(TMPDIR + 'tiny_invalid.dcm', 'wb') {|f| f.write('fail') }
        dcm = DObject.read(TMPDIR + 'tiny_invalid.dcm')
        expect(dcm.read?).to be_falsey
      end

      it "should fail gracefully when a directory is passed as an argument" do
        dcm = DObject.read(TMPDIR)
        expect(dcm.read?).to be_falsey
      end

      it "should set the file name string as the 'source' attribute" do
        dcm = DObject.read(DCM_ISO8859_1)
        expect(dcm.source).to eql DCM_ISO8859_1
      end

    end


    describe "#==()" do

      it "should be true when comparing two instances having the same attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        expect(dcm1 == dcm2).to be_truthy
      end

      it "should be false when comparing two instances having different attribute values (different children)" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm2.add(Sequence.new('0008,0006'))
        expect(dcm1 == dcm2).to be_falsey
      end

      it "should be false when comparing against an instance of incompatible type" do
        dcm = DObject.new
        expect(dcm == 42).to be_falsey
      end

    end


    describe "#eql?" do

      it "should be true when comparing two instances having the same attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        expect(dcm1.eql?(dcm2)).to be_truthy
      end

      it "should be false when comparing two instances having different attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm2.add(Sequence.new('0008,0006'))
        expect(dcm1.eql?(dcm2)).to be_falsey
      end

    end


    describe "#anonymize" do

      it "should raise an error if given a non-Anonymizer as argument" do
        dcm = DObject.new
        expect {dcm.anonymize(42)}.to raise_error
      end

      it "should create a default Anonymizer instance to use for anonymization when called without argument" do
        a= Anonymizer.new
        dcm = DObject.new
        Anonymizer.expects(:new).with(nil).returns(a)
        a.expects(:anonymize).with(dcm)
        dcm.anonymize
      end

      it "should use the anonymizer instance passed as argument for the anonymization" do
        a = Anonymizer.new
        dcm = DObject.new
        a.expects(:anonymize).with(dcm)
        dcm.anonymize(a)
      end

      it "should replace values to be anonymized and leave untouched values not to be anonymized" do
        dcm = DObject.new
        encoding = 'ISO_IR 100'
        date = '20113007'
        time = '123300'
        name = 'John Doe'
        slice_thickness = '3'
        dcm.add(Element.new('0008,0005', encoding))
        dcm.add(Element.new('0008,0012', date))
        dcm.add(Element.new('0008,0013', time))
        dcm.add(Element.new('0010,0010', name))
        dcm.add(Element.new('0018,0050', slice_thickness))
        dcm.anonymize
        expect(dcm.value('0008,0005')).to eql encoding
        expect(dcm.value('0008,0012')).not_to eql date
        expect(dcm.value('0008,0013')).not_to eql time
        expect(dcm.value('0010,0010')).not_to eql name
        expect(dcm.value('0018,0050')).to eql slice_thickness
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
        expect(binaries.uniq.length).to eql 1
      end

      it "should should have its rejoined, segmented binary be successfully read to a DICOM object" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        binary = dcm.encode_segments(16384).join
        dcm_reloaded = DObject.parse(binary, :bin => true)
        expect(dcm_reloaded.read?).to be_truthy
      end

    end


    describe "#hash" do

      it "should return the same Fixnum for two instances having the same attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        expect(dcm1.hash).to eql dcm2.hash
      end

      it "should return a different Fixnum for two instances having different attribute values" do
        dcm1 = DObject.new
        dcm2 = DObject.new
        dcm2.add(Sequence.new('0008,0006'))
        expect(dcm1.hash).not_to eql dcm2.hash
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


    # FIXME? Currently there is no specification for the format of the summary printout.
    #
    context "#summary" do

      it "should print the summary to the screen and return an array of information when called on a full DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        dcm.expects(:puts).at_least_once
        expect(dcm.summary).to be_an(Array)
      end

      it "should print the summary to the screen and return an array of information when called on an empty DICOM object" do
        dcm = DObject.new
        dcm.expects(:puts).at_least_once
        expect(dcm.summary).to be_an(Array)
      end

    end


    describe "#to_dcm" do

      it "should return itself" do
        dcm = DObject.new
        expect(dcm.to_dcm.equal?(dcm)).to be_truthy
      end

    end


    context "#transfer_syntax" do

      it "should return the default transfer syntax (Implicit, little endian) when the DICOM object has no transfer syntax tag" do
        dcm = DObject.new
        expect(dcm.transfer_syntax).to eql IMPLICIT_LITTLE_ENDIAN
      end

      it "should return the value of the transfer syntax tag of the DICOM object" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        expect(dcm.transfer_syntax).to eql EXPLICIT_BIG_ENDIAN
      end

      it "should set the determined transfer syntax (Explicit Little Endian) when loading a DICOM file (lacking transfer syntax) using two passes" do
        dcm = DObject.read(DCM_EXPLICIT_NO_HEADER)
        expect(dcm.transfer_syntax).to eql EXPLICIT_LITTLE_ENDIAN
      end

    end


    context "#transfer_syntax=()" do

      it "should change the transfer syntax of the empty DICOM object" do
        dcm = DObject.new
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        expect(dcm.transfer_syntax).to eql EXPLICIT_BIG_ENDIAN
      end

      it "should change the transfer syntax of the DICOM object which has been read from file" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        dcm.transfer_syntax = IMPLICIT_LITTLE_ENDIAN
        expect(dcm.transfer_syntax).to eql IMPLICIT_LITTLE_ENDIAN
      end

      it "should change the encoding of the data element's binary when switching endianness" do
        dcm = DObject.new
        dcm.add(Element.new('0018,1310', 500)) # This should give the binary string "\364\001"
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        expect(dcm['0018,1310'].bin).to eql "\001\364"
      end

      it "should not change the encoding of any meta group data element's binaries when switching endianness" do
        dcm = DObject.new
        dcm.add(Element.new('0002,9999', 500, :vr => 'US')) # This should give the binary string "\364\001"
        dcm.add(Element.new('0018,1310', 500))
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        expect(dcm['0002,9999'].bin).to eql "\364\001"
      end

      it "should change the encoding of pixel data binary when switching endianness" do
        dcm = DObject.new
        dcm.add(Element.new('0018,1310', 500)) # This should give the binary string "\364\001"
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        expect(dcm['0018,1310'].bin).to eql "\001\364"
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
        expect(@dcm.written?).to be_truthy
      end

      it "should be able to successfully read the written DICOM file if it was written correctly" do
        @dcm.write(@output)
        dcm_reloaded = DObject.read(@output)
        expect(dcm_reloaded.read?).to be_truthy
      end

      it "should create non-existing directories that are part of the file path, and write the file successfully" do
        path = File.join(TMPDIR, 'create/these/directories', 'test-directory-create.dcm')
        @dcm.write(path)
        expect(@dcm.written?).to be_truthy
        expect(File.exists?(path)).to be_truthy
      end

    end


    # Writing a limited DObject created from scratch.
    context "#write" do

      before :each do
        @path = TMPDIR + 'write.dcm'
        @dcm = DObject.new
        @dcm.add(Element.new('0008,0016', '1.2.34567'))
        @dcm.add(Element.new('0008,0018', '1.2.34567.89'))
      end

      it "should succeed in writing a limited DICOM object, created from scratch" do
        @dcm.write(@path)
        expect(@dcm.written?).to be_truthy
        expect(File.exists?(@path)).to be_truthy
      end

      it "should add the File Meta Information Version to the File Meta Group, when it is undefined" do
        @dcm.write(@path)
        expect(@dcm.exists?('0002,0001')).to be_truthy
      end

      it "should use the SOP Class UID to create the Media Storage SOP Class UID of the File Meta Group when it is undefined" do
        @dcm.write(@path)
        expect(@dcm.value('0002,0002')).to eql @dcm.value('0008,0016')
      end

      it "should use the SOP Instance UID to create the Media Storage SOP Instance UID of the File Meta Group when it is undefined" do
        @dcm.write(@path)
        expect(@dcm.value('0002,0003')).to eql @dcm.value('0008,0018')
      end

      it "should add (the default) Transfer Syntax UID to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        expect(@dcm.value('0002,0010')).to eql IMPLICIT_LITTLE_ENDIAN
      end

      it "should add the Implementation Class UID to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        expect(@dcm.value('0002,0012')).to eql UID_ROOT
      end

      it "should add the Implementation Version Name to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        expect(@dcm.value('0002,0013')).to eql NAME
      end

      it "should add the Source Application Entity Title to the File Meta Group when it is undefined" do
        @dcm.write(@path)
        expect(@dcm.value('0002,0016')).to eql DICOM.source_app_title
      end

      it "should add a user-defined Source Application Entity Title to the File Meta Group when it is undefined (in the DObject)" do
        original_title = DICOM.source_app_title
        DICOM.source_app_title = 'MY_TITLE'
        @dcm.write(@path)
        expect(@dcm.value('0002,0016')).to eql 'MY_TITLE'
        DICOM.source_app_title = original_title
      end

      it "should not add the Implementation Class UID to the File Meta Group, when (it is undefined and) the Implementation Version Name is defined" do
        @dcm.add(Element.new('0002,0013', 'SomeProgram'))
        @dcm.write(@path)
        expect(@dcm.exists?('0002,0012')).to be_falsey
      end

      it "should not add the Implementation Version Name to the File Meta Group, when (it is undefined and) the Implementation Class UID is defined" do
        @dcm.add(Element.new('0002,0012', '1.2.54321'))
        @dcm.write(@path)
        expect(@dcm.exists?('0002,0013')).to be_falsey
      end

      it "should not touch the meta group when the :ignore_meta option is passed" do
        @dcm.expects(:insert_missing_meta).never
        @dcm.write(@path, :ignore_meta => true)
      end

      it "should by default call the method to fix anything missing in the meta group" do
        @dcm.expects(:insert_missing_meta).once
        @dcm.write(@path)
      end

      it "should by default not write empty parents" do
        s = Sequence.new('0008,1140', :parent => @dcm)
        s.add_item
        s.add_item
        s[0].add(Element.new('0008,1150', '1.267.921'))
        @dcm.add(Sequence.new('0008,2112'))
        @dcm.write(@path)
        r_dcm = DObject.read(@path)
        # The empty sequence should have been removed:
        expect(r_dcm.exists?('0008,2112')).to be_falsey
        # Only one item should remain beneath this sequence, when the empty one is removed:
        expect(r_dcm['0008,1140'].children.length).to eql 1
      end

      it "should write empty parents when the :include_empty_parents option is used" do
        s = Sequence.new('0008,1140', :parent => @dcm)
        s.add_item
        s.add_item
        s[0].add(Element.new('0008,1150', '1.267.921'))
        @dcm.add(Sequence.new('0008,2112'))
        @dcm.write(@path, :include_empty_parents => true)
        r_dcm = DObject.read(@path)
        # The empty sequence should remain:
        expect(r_dcm.exists?('0008,2112')).to be_truthy
        # Both items should remain beneath this sequence:
        expect(r_dcm['0008,1140'].children.length).to eql 2
      end

    end


    after :all do
      DICOM.logger = Logger.new(STDOUT)
      DICOM.logger.level = Logger::FATAL
    end

  end

end
