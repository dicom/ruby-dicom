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
        expect(AuditTrail.new).to be_an AuditTrail
      end

      it "should by default set an empty hash for the dictionary attribute" do
        expect(@a.dictionary).to eql Hash.new
      end

    end


    context "::read" do

      it "should raise an Error when given an invalid file as argument" do
        expect {AuditTrail.read("not-a-file")}.to raise_error
      end

      it "should return an AuditTrail instance" do
        expect(@ar).to be_an AuditTrail
      end

      it "should load the dictionary with the tags specified in this json" do
        expect(@ar.dictionary.length).to eql 5
        tags = @ar.dictionary.keys
        expect(tags.include?("0008,0080")).to be_truthy
        expect(tags.include?("0008,0090")).to be_truthy
        expect(tags.include?("0008,1010")).to be_truthy
        expect(tags.include?("0010,0010")).to be_truthy
        expect(tags.include?("0010,0020")).to be_truthy
      end

      it "should load the tag records specified in this json" do
        expect(@ar.dictionary["0008,0080"].length).to eql 2
        expect(@ar.dictionary["0008,0080"]["Salt Lake Clinic"]).to eql "Institution1"
        expect(@ar.dictionary["0008,0080"]["Chicago Hope"]).to eql "Institution2"
        expect(@ar.dictionary["0008,0090"].length).to eql 3
        expect(@ar.dictionary["0008,0090"]["Dr. Smith"]).to eql "Physician1"
        expect(@ar.dictionary["0008,0090"]["Dr. Feelgood"]).to eql "Physician2"
        expect(@ar.dictionary["0008,0090"]["Dr.Evil"]).to eql "Physician3"
        expect(@ar.dictionary["0008,1010"].length).to eql 1
        expect(@ar.dictionary["0008,1010"]["E-Scan"]).to eql "Station1"
        expect(@ar.dictionary["0010,0010"].length).to eql 4
        expect(@ar.dictionary["0010,0010"]["John Doe"]).to eql "Patient1"
        expect(@ar.dictionary["0010,0010"]["Ruby^Rocket"]).to eql "Patient2"
        expect(@ar.dictionary["0010,0010"]["Donny Dicom"]).to eql "Patient3"
        expect(@ar.dictionary["0010,0010"]["Carl Catscan"]).to eql "Patient4"
        expect(@ar.dictionary["0010,0020"].length).to eql 4
        expect(@ar.dictionary["0010,0020"]["12345"]).to eql "ID1"
        expect(@ar.dictionary["0010,0020"]["67890"]).to eql "ID2"
        expect(@ar.dictionary["0010,0020"]["010101"]).to eql "ID3"
        expect(@ar.dictionary["0010,0020"]["111111"]).to eql "ID4"
      end

    end


    context "#add_record" do

      it "should add the tag record to the empty dictionary" do
        tag = "0010,0010"
        original = "John"
        replacement = "Patient1"
        @a.add_record(tag, original, replacement)
        expect(@a.dictionary.length).to eql 1
        expect(@a.dictionary[tag].length).to eql 1
        expect(@a.dictionary[tag][original]).to eql replacement
      end

      it "should add the tag record to a dictionary already containing a record with this tag" do
        tag = "0010,0010"
        original1 = "John"
        original2 = "Jack"
        replacement1 = "Patient1"
        replacement2 = "Patient2"
        @a.add_record(tag, original1, replacement1)
        @a.add_record(tag, original2, replacement2)
        expect(@a.dictionary.length).to eql 1
        expect(@a.dictionary[tag].length).to eql 2
        expect(@a.dictionary[tag][original1]).to eql replacement1
        expect(@a.dictionary[tag][original2]).to eql replacement2
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
        expect(@a.dictionary.length).to eql 2
        expect(@a.dictionary[tag1].length).to eql 1
        expect(@a.dictionary[tag2].length).to eql 1
        expect(@a.dictionary[tag1][original1]).to eql replacement1
        expect(@a.dictionary[tag2][original2]).to eql replacement2
      end

    end


    context "#load" do

      it "should raise an Error when given an invalid file as argument" do
        expect {@a.load("not-a-file")}.to raise_error
      end

      it "should load the dictionary with the tags specified in this json" do
        @a.load(JSON_AUDIT_TRAIL)
        expect(@a.dictionary.length).to eql 5
      end

    end


    context "#original" do

      it "should return nil when queried with a non-existing tag" do
        expect(@ar.original("ffff,aaaa", "Patient3")).to be_nil
      end

      it "should return nil when queried with a non-existing replacement value" do
        expect(@ar.original("0010,0010", "Patient99")).to be_nil
      end

      it "should return the original element value" do
        expect(@ar.original("0008,0080", "Institution1")).to eql "Salt Lake Clinic"
        expect(@ar.original("0010,0010", "Patient3")).to eql "Donny Dicom"
      end

    end


    context "#records" do

      it "should return an empty hash when called with a non-existing tag" do
        expect(@ar.records("ffff,aaaa")).to eql Hash.new
      end

      it "should return the expected records" do
        expect(@ar.records("0008,0080")).to eql @ar.dictionary["0008,0080"]
        expect(@ar.records("0008,0090")).to eql @ar.dictionary["0008,0090"]
        expect(@ar.records("0008,1010")).to eql @ar.dictionary["0008,1010"]
        expect(@ar.records("0010,0010")).to eql @ar.dictionary["0010,0010"]
        expect(@ar.records("0010,0020")).to eql @ar.dictionary["0010,0020"]
      end

    end


    context "#replacement" do

      it "should return nil when queried with a non-existing tag" do
        expect(@ar.replacement("ffff,aaaa", "Donny Dicom")).to be_nil
      end

      it "should return nil when queried with a non-existing replacement value" do
        expect(@ar.replacement("0010,0010", "No-name")).to be_nil
      end

      it "should return the original element value" do
        expect(@ar.replacement("0008,0080", "Salt Lake Clinic")).to eql "Institution1"
        expect(@ar.replacement("0010,0010", "Donny Dicom")).to eql "Patient3"
      end

    end


    context "#write" do

      it "should write the content of the dictionary attribute to the given file as a json string" do
        written_file = TMPDIR + "audit_trail.json"
        @ar.write(written_file)
        str_original = File.open(JSON_AUDIT_TRAIL, 'r') { |f| f.read }
        str_written = File.open(written_file, 'r') { |f| f.read }
        expect(str_written.length).to be > 2
        expect(str_written).to eql str_original
      end

      it "should be able to write to a path that contains folders that haven't been created yet" do
        written_file = File.join(TMPDIR, "audit_trail/create_this_folder/test.json")
        @ar.write(written_file)
        expect(File.exists?(written_file)).to be_truthy
      end

    end

  end

end