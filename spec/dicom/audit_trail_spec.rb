# encoding: UTF-8

require 'spec_helper'


module DICOM

  describe AuditTrail do

    before :each do
      @a = AuditTrail.new
      @ar = AuditTrail.read(JSON_AUDIT_TRAIL)
    end


    context "::new" do

      it "should create an AuditTrail instance" do
        AuditTrail.new.should be_an AuditTrail
      end

      it "should by default set an empty hash for the dictionary attribute" do
        @a.dictionary.should eql Hash.new
      end

    end


    context "::read" do

      it "should raise an Error when given an invalid file as argument" do
        expect {AuditTrail.read("not-a-file")}.to raise_error
      end

      it "should return an AuditTrail instance" do
        @ar.should be_an AuditTrail
      end

      it "should load the dictionary with the tags specified in this json" do
        @ar.dictionary.length.should eql 5
        tags = @ar.dictionary.keys
        tags.include?("0008,0080").should be_true
        tags.include?("0008,0090").should be_true
        tags.include?("0008,1010").should be_true
        tags.include?("0010,0010").should be_true
        tags.include?("0010,0020").should be_true
      end

      it "should load the tag records specified in this json" do
        @ar.dictionary["0008,0080"].length.should eql 2
        @ar.dictionary["0008,0080"]["Salt Lake Clinic"].should eql "Institution1"
        @ar.dictionary["0008,0080"]["Chicago Hope"].should eql "Institution2"
        @ar.dictionary["0008,0090"].length.should eql 3
        @ar.dictionary["0008,0090"]["Dr. Smith"].should eql "Physician1"
        @ar.dictionary["0008,0090"]["Dr. Feelgood"].should eql "Physician2"
        @ar.dictionary["0008,0090"]["Dr.Evil"].should eql "Physician3"
        @ar.dictionary["0008,1010"].length.should eql 1
        @ar.dictionary["0008,1010"]["E-Scan"].should eql "Station1"
        @ar.dictionary["0010,0010"].length.should eql 4
        @ar.dictionary["0010,0010"]["John Doe"].should eql "Patient1"
        @ar.dictionary["0010,0010"]["Ruby^Rocket"].should eql "Patient2"
        @ar.dictionary["0010,0010"]["Donny Dicom"].should eql "Patient3"
        @ar.dictionary["0010,0010"]["Carl Catscan"].should eql "Patient4"
        @ar.dictionary["0010,0020"].length.should eql 4
        @ar.dictionary["0010,0020"]["12345"].should eql "ID1"
        @ar.dictionary["0010,0020"]["67890"].should eql "ID2"
        @ar.dictionary["0010,0020"]["010101"].should eql "ID3"
        @ar.dictionary["0010,0020"]["111111"].should eql "ID4"
      end

    end


    context "#add_record" do

      it "should add the tag record to the empty dictionary" do
        tag = "0010,0010"
        original = "John"
        replacement = "Patient1"
        @a.add_record(tag, original, replacement)
        @a.dictionary.length.should eql 1
        @a.dictionary[tag].length.should eql 1
        @a.dictionary[tag][original].should eql replacement
      end

      it "should add the tag record to a dictionary already containing a record with this tag" do
        tag = "0010,0010"
        original1 = "John"
        original2 = "Jack"
        replacement1 = "Patient1"
        replacement2 = "Patient2"
        @a.add_record(tag, original1, replacement1)
        @a.add_record(tag, original2, replacement2)
        @a.dictionary.length.should eql 1
        @a.dictionary[tag].length.should eql 2
        @a.dictionary[tag][original1].should eql replacement1
        @a.dictionary[tag][original2].should eql replacement2
      end

      it "should add the tag record to a dictionary already containing a record with another tag" do
        tag1 = "0010,0010"
        tag2 = "0010,0020"
        original1 = "John"
        original2 = "12345"
        replacement1 = "Patient1"
        replacement2 = "ID1"
        @a.add_record(tag1, original1, replacement1)
        @a.add_record(tag2, original2, replacement2)
        @a.dictionary.length.should eql 2
        @a.dictionary[tag1].length.should eql 1
        @a.dictionary[tag2].length.should eql 1
        @a.dictionary[tag1][original1].should eql replacement1
        @a.dictionary[tag2][original2].should eql replacement2
      end

    end


    context "#load" do

      it "should raise an Error when given an invalid file as argument" do
        expect {@a.load("not-a-file")}.to raise_error
      end

      it "should load the dictionary with the tags specified in this json" do
        @a.load(JSON_AUDIT_TRAIL)
        @a.dictionary.length.should eql 5
      end

    end


    context "#original" do

      it "should return nil when queried with a non-existing tag" do
        @ar.original("ffff,aaaa", "Patient3").should be_nil
      end

      it "should return nil when queried with a non-existing replacement value" do
        @ar.original("0010,0010", "Patient99").should be_nil
      end

      it "should return the original element value" do
        @ar.original("0008,0080", "Institution1").should eql "Salt Lake Clinic"
        @ar.original("0010,0010", "Patient3").should eql "Donny Dicom"
      end

    end


    context "#records" do

      it "should return an empty hash when called with a non-existing tag" do
        @ar.records("ffff,aaaa").should eql Hash.new
      end

      it "should return the expected records" do
        @ar.records("0008,0080").should eql @ar.dictionary["0008,0080"]
        @ar.records("0008,0090").should eql @ar.dictionary["0008,0090"]
        @ar.records("0008,1010").should eql @ar.dictionary["0008,1010"]
        @ar.records("0010,0010").should eql @ar.dictionary["0010,0010"]
        @ar.records("0010,0020").should eql @ar.dictionary["0010,0020"]
      end

    end


    context "#replacement" do

      it "should return nil when queried with a non-existing tag" do
        @ar.replacement("ffff,aaaa", "Donny Dicom").should be_nil
      end

      it "should return nil when queried with a non-existing replacement value" do
        @ar.replacement("0010,0010", "No-name").should be_nil
      end

      it "should return the original element value" do
        @ar.replacement("0008,0080", "Salt Lake Clinic").should eql "Institution1"
        @ar.replacement("0010,0010", "Donny Dicom").should eql "Patient3"
      end

    end


    context "#write" do

      it "should write the content of the dictionary attribute to the given file as a json string" do
        written_file = TMPDIR + "audit_trail.json"
        @ar.write(written_file)
        str_original = File.open(JSON_AUDIT_TRAIL, 'r') { |f| f.read }
        str_written = File.open(written_file, 'r') { |f| f.read }
        str_written.length.should > 2
        str_written.should eql str_original
      end

    end

  end

end