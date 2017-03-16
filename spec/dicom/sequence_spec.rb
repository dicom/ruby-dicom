# encoding: UTF-8

require 'spec_helper'


module DICOM

  describe Sequence do

    context "::new" do

      it "should raise ArgumentError when creation is attempted with an invalid tag string" do
        expect {Sequence.new("asdf,asdf")}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when creation is attempted with a non-string as tag" do
        expect {Sequence.new(3.1337)}.to raise_error(ArgumentError)
      end

      it "should get its name attribute from the dictionary on creation" do
        s = Sequence.new("0008,0006")
        expect(s.name).to eql "Language Code Sequence"
      end

      it "should by default set its length attribute as -1, which really means 'Undefined'" do
        s = Sequence.new("0008,0006")
        expect(s.length).to eql -1
      end

      it "should use the :length option, if specified, to set the length attribute" do
        s = Sequence.new("0008,0006", :length => 30)
        expect(s.length).to eql 30
      end

      it "should set the bin attribute as nil, as a Sequence, by our definition, doesn't have binary data" do
        s = Sequence.new("0008,0006")
        expect(s.bin).to be_nil
      end

      it "should get its VR attribute from the dictionary on creation" do
        s = Sequence.new("0008,0006")
        expect(s.vr).to eql "SQ"
      end

      it "should set its tag attribute on creation" do
        s = Sequence.new("0008,0006")
        expect(s.tag).to eql "0008,0006"
      end

      it "should set its parent attribute to nil when no parent is specified" do
        s = Sequence.new("0008,0006")
        expect(s.parent).to be_nil
      end

      it "should set the parent attribute when the :parent option is used on creation" do
        i = Item.new
        s = Sequence.new("0008,0006", :parent => i)
        expect(s.parent).to eql i
      end

      it "should update the parent attribute when the parent=() method is called" do
        i = Item.new
        s = Sequence.new("0008,0006")
        s.parent = i
        expect(s.parent).to eql i
      end

      it "should register itself as a child of the new parent element when the parent=() method is called" do
        i = Item.new
        s = Sequence.new("3006,0040")
        s.parent = i
        expect(i.children?).to eql true
      end

      it "should remove itself as a child of the old parent element when a new parent is set with the parent=() method" do
        i_old = Item.new
        s = Sequence.new("3006,0040", :parent => i_old)
        i_new = Item.new
        s.parent = i_new
        expect(i_old.children?).to be_falsey
      end

      it "should return an empty array when the parents method is called and no parent has been specified" do
        s = Sequence.new("0008,0006")
        expect(s.parents).to eql Array.new
      end

      it "should return a 3-element array with the chain of parents, where the top parent is the last element, and immediate parent is the first" do
        dcm = DObject.new
        s1 = Sequence.new("3006,0039", :parent => dcm)
        i = Item.new(:parent => s1)
        s2 = Sequence.new("3006,0040", :parent => i)
        expect(s2.parents.length).to eql 3
        expect(s2.parents.first).to eql i
        expect(s2.parents.last).to eql dcm
      end

      it "should return itself when the top_parent method is called and no external parent has been specified" do
        s = Sequence.new("0008,0006")
        expect(s.top_parent).to eql s
      end

      it "should return the top parent in the chain of parents when the top_parent method is called on an element with multiple parents" do
        dcm = DObject.new
        s1 = Sequence.new("3006,0039", :parent => dcm)
        i = Item.new(:parent => s1)
        s2 = Sequence.new("3006,0040", :parent => i)
        expect(s2.top_parent).to eql dcm
      end

      it "should return a Stream instance when the stream method is called" do
        s = Sequence.new("0008,0006")
        expect(s.stream.class).to eq(Stream)
      end

      it "should use the name (supplied as an option), rather than the matching dictionary entry, on creation" do
        s = Sequence.new("0008,0006", :name => "Custom Sequence")
        expect(s.name).to eql "Custom Sequence"
      end

      it "should use the VR (supplied as an option), rather than the matching dictionary entry, on creation" do
        s = Sequence.new("0008,0006", :vr => "OB")
        expect(s.vr).to eql "OB"
      end

      it "should set the name attribute as 'Private' when a private tag is created" do
        s = Sequence.new("0029,0010", :vr => "UL")
        expect(s.name).to eql "Private"
      end

      it "should set the name attribute as 'Unknown' when a non-private tag is created that can't be matched in the dictionary" do
        s = Sequence.new("ABF0,1234")
        expect(s.name).to eql "Unknown"
      end

      it "should return false when the children? method is called as a newly created Sequence do not have child elements" do
        s = Sequence.new("0008,0006")
        expect(s.children?).to be_falsey
      end

      it "should return true when the is_parent? method is called as a Sequence by definition is a parent" do
        s = Sequence.new("0008,0006")
        expect(s.is_parent?).to eql true
      end

    end


    describe "#==" do

      it "should be true when comparing two instances having the same attribute values" do
        s1 = Sequence.new("0008,0006")
        s2 = Sequence.new("0008,0006")
        expect(s1 == s2).to be_truthy
      end

      it "should be false when comparing two instances having different attribute values (same tag but different children)" do
        s1 = Sequence.new("0008,0006")
        s2 = Sequence.new("0008,0006")
        s2.add_item
        expect(s1 == s2).to be_falsey
      end

      it "should be false when comparing two instances having different attribute values (different tag but both no children)" do
        s1 = Sequence.new("0008,0006")
        s2 = Sequence.new("3006,0040")
        expect(s1 == s2).to be_falsey
      end

      it "should be false when comparing against an instance of incompatible type" do
        s = Sequence.new("0008,0006")
        expect(s == 42).to be_falsey
      end

    end


    describe "#eql?" do

      it "should be true when comparing two instances having the same attribute values" do
        s1 = Sequence.new("0008,0006")
        s2 = Sequence.new("0008,0006")
        expect(s1.eql?(s2)).to be_truthy
      end

      it "should be false when comparing two instances having different attribute values" do
        s1 = Sequence.new("0008,0006")
        s2 = Sequence.new("0008,0006")
        s2.add_item
        expect(s1.eql?(s2)).to be_falsey
      end

    end


    describe "#hash" do

      it "should return the same Integer for two instances having the same attribute values" do
        s1 = Sequence.new("0008,0006")
        s2 = Sequence.new("0008,0006")
        expect(s1.hash).to eql s2.hash
      end

      it "should return a different Integer for two instances having different attribute values" do
        s1 = Sequence.new("0008,0006")
        s2 = Sequence.new("0008,0006")
        s2.add_item
        expect(s1.hash).not_to eql s2.hash
      end

    end


    describe "#parse" do

      it "should parse and attach the item" do
        bin = "\xFE\xFF\x00\xE0\xA6\x00\x00\x00"
        s = Sequence.new('0008,0006')
        s.parse(bin, '1.2.840.10008.1.2')
        expect(s.count).to eql 1
        expect(s.items.length).to eql 1
        expect(s[0].parent).to eql s
      end

    end


    describe "#to_sequence" do

      it "should return itself" do
        s = Sequence.new("0008,0006")
        expect(s.to_sequence.equal?(s)).to be_truthy
      end

    end

  end

end
