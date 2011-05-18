# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe Anonymizer do

    before :each do
      @anon = TMPDIR + "anon"
      @anon_s = TMPDIR + "anon/"
      @anon_other = TMPDIR + "anon2/"
      @skip = @anon_s + "skip_these"
      @skip_s = @anon_s + "skip_these/"
      @wpath = TMPDIR + "awrite"
      @wpath_s = TMPDIR + "awrite/"
      FileUtils.rmtree(@anon) if File.directory?(@anon)
      FileUtils.rmtree(@anon_other) if File.directory?(@anon_other)
      FileUtils.mkdir_p(@skip)
      FileUtils.mkdir_p(@anon_other)
      FileUtils.copy(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, @anon)
      FileUtils.copy(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, @anon_other)
      FileUtils.copy(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, @skip)
      FileUtils.copy(DCM_EXPLICIT_MR_RLE_MONO2, @anon)
      FileUtils.copy(DCM_EXPLICIT_MR_RLE_MONO2, @anon_other)
      FileUtils.copy(DCM_EXPLICIT_MR_RLE_MONO2, @skip)
      @anon1 = @anon_s + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @anon2 = @anon_s + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
      @anon3 = @anon_other + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @anon4 = @anon_other + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
      @skip1 = @skip_s + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @skip2 = @skip_s + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
      @w1 = @wpath_s + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @w2 = @wpath_s + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
      Logging.logger = mock
      Logging.logger.stubs(:warn)
      Logging.logger.stubs(:error)
      Logging.logger.stubs(:info)
    end


    describe "#new" do

      it "should set the blank attribute as false" do
        a = Anonymizer.new
        a.blank.should be_false
      end

      it "should set the enumeration attribute as false" do
        a = Anonymizer.new
        a.enumeration.should be_false
      end

      it "should set the identity_file attribute as nil" do
        a = Anonymizer.new
        a.identity_file.should be_nil
      end

      it "should set the log attribute as an empty array" do
        a = Anonymizer.new
        a.log.should be_an(Array)
        a.log.length.should eql 0
      end

      it "should set the remove_private attribute as false" do
        a = Anonymizer.new
        a.remove_private.should be_false
      end

      it "should set the write_path attribute as nil" do
        a = Anonymizer.new
        a.write_path.should be_nil
      end

    end


    describe "#add_exception" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.add_exception(42)}.to raise_error(ArgumentError)
      end

      it "should not anonymize files in the exception directory, but still anonymize the other files (with the given paths ending with a separator)" do
        a = Anonymizer.new
        a.add_exception(@skip_s)
        a.add_folder(@anon_s)
        a.execute
        a1 = DObject.new(@anon1)
        a2 = DObject.new(@anon2)
        s1 = DObject.new(@skip1)
        s2 = DObject.new(@skip2)
        a1.value("0010,0010").should eql a.value("0010,0010")
        a2.value("0010,0010").should eql a.value("0010,0010")
        s1.value("0010,0010").should_not eql a.value("0010,0010")
        s2.value("0010,0010").should_not eql a.value("0010,0010")
      end

      it "should not anonymize files in the exception directory, but still anonymize the other files (with the given paths not ending with a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.add_exception(@skip)
        a.execute
        a1 = DObject.new(@anon1)
        a2 = DObject.new(@anon2)
        s1 = DObject.new(@skip1)
        s2 = DObject.new(@skip2)
        a1.value("0010,0010").should eql a.value("0010,0010")
        a2.value("0010,0010").should eql a.value("0010,0010")
        s1.value("0010,0010").should_not eql a.value("0010,0010")
        s2.value("0010,0010").should_not eql a.value("0010,0010")
      end

    end


    describe "#add_folder" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.add_folder(42)}.to raise_error(ArgumentError)
      end

      it "should anonymize files in the specified folder as well as any sub-folders (with the given path ending with a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon_s)
        a.execute
        a1 = DObject.new(@anon1)
        a2 = DObject.new(@anon2)
        s1 = DObject.new(@skip1)
        s2 = DObject.new(@skip2)
        a1.value("0010,0010").should eql a.value("0010,0010")
        a2.value("0010,0010").should eql a.value("0010,0010")
        s1.value("0010,0010").should eql a.value("0010,0010")
        s2.value("0010,0010").should eql a.value("0010,0010")
      end

      it "should anonymize files in the specified folder as well as any sub-folders (with the given path ending without a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.execute
        a1 = DObject.new(@anon1)
        a2 = DObject.new(@anon2)
        s1 = DObject.new(@skip1)
        s2 = DObject.new(@skip2)
        a1.value("0010,0010").should eql a.value("0010,0010")
        a2.value("0010,0010").should eql a.value("0010,0010")
        s1.value("0010,0010").should eql a.value("0010,0010")
        s2.value("0010,0010").should eql a.value("0010,0010")
      end

      it "should anonymize files in all specified folders, when multiple folders are added" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.add_folder(@anon_other)
        a.execute
        a1 = DObject.new(@anon1)
        a2 = DObject.new(@anon2)
        a3 = DObject.new(@anon3)
        a4 = DObject.new(@anon4)
        a1.value("0010,0010").should eql a.value("0010,0010")
        a2.value("0010,0010").should eql a.value("0010,0010")
        a3.value("0010,0010").should eql a.value("0010,0010")
        a4.value("0010,0010").should eql a.value("0010,0010")
      end

    end


    describe "#enum" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value("asdf,asdf")}.to raise_error(ArgumentError)
      end

      it "should return the enumeration boolean for the specified tag" do
        a = Anonymizer.new
        a.set_tag("0010,0010", :enum => true)
        a.enum("0010,0010").should be_true
        a.set_tag("0010,0010", :enum => false)
        a.enum("0010,0010").should be_false
        a.set_tag("0010,0010", :enum => true)
        a.enum("0010,0010").should be_true
      end

    end


    describe "#execute" do

      it "should print information to the screen when verbose has not been set as false" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        Logging.logger.expects(:info).at_least_once
        a.execute
      end

      it "should not print information to the screen when verbose has been set as false" do
        a = Anonymizer.new(:verbose => false)
        a.expects(:puts).never
        a.add_folder(@anon_other)
        a.execute
      end

      it "should anonymize the folder's files according to the list of tags in the anonymization instance" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.execute
        obj = DObject.new(@anon3)
        obj.value("0010,0010").should eql a.value("0010,0010")
        obj.value("0008,0020").should eql a.value("0008,0020")
      end

      it "should not create data elements which are present on the 'list to be anonymized' but not in the target file" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.execute
        obj = DObject.new(@anon3) # the tag we are testing is not originally present in this file
        a.value("0008,0012").should be_true # make sure the tag we are testing is defined
        obj.exists?("0008,0012").should be_false
      end

      it "should fill the log with information" do
        a = Anonymizer.new(:verbose => false)
        a.add_folder(@anon_other)
        Logging.logger.expects(:info).at_least_once
        a.execute
      end

      it "should use empty strings for anonymization when we have set the blank attribute as true" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.blank = true
        a.execute
        obj = DObject.new(@anon3)
        obj.value("0010,0010").should_not eql a.value("0010,0010")
        obj.value("0010,0010").to_s.length.should eql 0
      end

      it "should use enumerated strings for anonymization when we have set the enumeration attribute as true" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.enumeration = true
        a.execute
        a1 = DObject.new(@anon1)
        a2 = DObject.new(@anon2)
        s1 = DObject.new(@skip1)
        s2 = DObject.new(@skip2)
        a1.value("0010,0010").should_not eql a.value("0010,0010")
        a1.value("0010,0010").should eql s1.value("0010,0010")
        a2.value("0010,0010").should eql s2.value("0010,0010")
        a1.value("0010,0010").should_not eql a2.value("0010,0010")
        s1.value("0010,0010").should_not eql s2.value("0010,0010")
        a1.value("0010,0010").include?(a.value("0010,0010")).should be_true
        a1.value("0010,0010")[-1..-1].to_i.should_not eql a2.value("0010,0010")[-1..-1].to_i
      end

      it "should write the anonymized files to the specified folder and leave the original DICOM files untouched, when the write_path attribute is specified (with the path not ending with a file separator)" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.write_path = @wpath
        obj = DObject.new(@anon3)
        old_value = obj.value("0010,0010")
        a.execute
        obj = DObject.new(@anon3)
        after_value = obj.value("0010,0010")
        after_value.should eql old_value
        w = DObject.new(@w1)
        w.value("0010,0010").should eql a.value("0010,0010")
      end

      it "should write the anonymized files to the specified folder (with the path ending with a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.write_path = @wpath_s
        a.execute
        w = DObject.new(@w1)
        w.value("0010,0010").should eql a.value("0010,0010")
      end

      # FIXME? There is no specification yet for the format or content of this file printout.
      it "should write the relationship between original and enumerated values to the specified file" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.enumeration = true
        a.identity_file = TMPDIR + "identification.txt"
        a.execute
        File.exists?(TMPDIR + "identification.txt").should be_true
      end

    end


    # FIXME? Currently there is no specification for the format of the element printout (this method is not very important, really).
    #
    describe "#print" do

      it "should print information to the screen" do
        a = Anonymizer.new
        a.expects(:puts).at_least_once
        a.print
      end

    end


    describe "#remove_tag" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.remove_tag(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.remove_tag("asdf,asdf")}.to raise_error(ArgumentError)
      end

      it "should remove the tag, with its value and enumeration status, from the list of tags to be anonymized" do
        a = Anonymizer.new
        a.remove_tag("0010,0010")
        a.value("0010,0010").should be_nil
        a.enum("0010,0010").should be_nil
      end

    end


    describe "#set_tag" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.set_tag(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.set_tag("asdf,asdf")}.to raise_error(ArgumentError)
      end

      it "should add the tag, with its value, to the list of tags to be anonymized" do
        a = Anonymizer.new
        a.set_tag("0040,2008", :value => "none")
        a.value("0040,2008").should eql "none"
      end

      it "should add the tag, using the default empty string as value, when no value is specified" do
        a = Anonymizer.new
        a.set_tag("0040,2008")
        a.value("0040,2008").should eql ""
      end

      it "should update the tag, with the new value, when a pre-existing tag is specified" do
        a = Anonymizer.new
        a.set_tag("0010,0010", :value => "KingAnonymous")
        a.value("0010,0010").should eql "KingAnonymous"
      end

      it "should update the tag, keeping the old value, when a pre-existing tag is specified but no value given" do
        a = Anonymizer.new
        old_value = a.value("0010,0010")
        a.set_tag("0010,0010")
        a.value("0010,0010").should eql old_value
      end

      it "should update the enumeration status of the pre-listed tag, when specified" do
        a = Anonymizer.new
        a.set_tag("0010,0010", :enum => true)
        a.enum("0010,0010").should be_true
      end

      it "should set the enumeration status for the newly created tag entry, when specified" do
        a = Anonymizer.new
        a.set_tag("0040,2008", :enum => true)
        a.enum("0040,2008").should be_true
      end

      it "should not change the enumeration status of a tag who's old value is true, when enumeration is not specified" do
        a = Anonymizer.new
        a.set_tag("0010,0010", :enum => true)
        a.set_tag("0010,0010")
        a.enum("0010,0010").should be_true
      end

      it "should not change the enumeration status of a tag who's old value is false, when enumeration is not specified" do
        a = Anonymizer.new
        a.set_tag("0010,0010", :enum => false)
        a.set_tag("0010,0010")
        a.enum("0010,0010").should be_false
      end

      it "should set the enumeration status for the newly created tag entry as false, when enumeration not specified" do
        a = Anonymizer.new
        a.set_tag("0040,2008")
        a.enum("0040,2008").should be_false
      end

    end


    describe "#value" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value("asdf,asdf")}.to raise_error(ArgumentError)
      end

      it "should return the anonymization value to be used for the specified tag" do
        a = Anonymizer.new
        a.set_tag("0010,0010", :value => "custom_value")
        a.value("0010,0010").should eql "custom_value"
      end

    end

  end

end
