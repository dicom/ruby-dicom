# encoding: UTF-8

require 'spec_helper'


module DICOM

  describe Item do

    describe "::new" do

      it "should set its name attribute as 'Item'" do
        i = Item.new
        expect(i.name).to eql "Item"
      end

      it "should by default set its length attribute as -1, which really means 'Undefined'" do
        i = Item.new
        expect(i.length).to eql -1
      end

      it "should use the :length option, if specified, to set the length attribute" do
        i = Item.new(:length => 30)
        expect(i.length).to eql 30
      end

      it "should set the bin attribute as nil, as an Item, unless specified by option, doesn't have binary data" do
        i = Item.new
        expect(i.bin).to be_nil
      end

      it "should set its VR attribute as '  '" do
        i = Item.new
        expect(i.vr).to eql "  "
      end

      it "should set its tag attribute on creation" do
        i = Item.new
        expect(i.tag).to eql "FFFE,E000"
      end

      it "should set its index attribute as nil when no parent or index is specified as options" do
        i = Item.new
        expect(i.index).to be_nil
      end

      it "should not set its index if the :index option is specified but not the :parent option" do
        i = Item.new(:index => 2)
        expect(i.index).to be_nil
      end

      it "should set its index if the :index option is specified along with a :parent option" do
        s = Sequence.new("0008,0006")
        i = Item.new(:index => 1, :parent => s)
        expect(i.index).to eql 0
      end

      it "should set a correct index value when an Item is created with a reference to a Sequence which is already occupied by several items" do
        s = Sequence.new("0008,0006")
        i1 = Item.new(:parent => s)
        i2 = Item.new(:parent => s)
        i = Item.new(:parent => s)
        expect(i.index).to eql 2
      end

      it "should set its parent attribute to nil when no parent is specified" do
        i = Item.new
        expect(i.parent).to be_nil
      end

      it "should set the parent attribute when the :parent option is used on creation" do
        s = Sequence.new("0008,0006")
        i = Item.new(:parent => s)
        expect(i.parent).to eql s
      end

      it "should update the parent attribute when the parent=() method is called" do
        s = Sequence.new("0008,0006")
        i = Item.new
        i.parent = s
        expect(i.parent).to eql s
      end

      it "should register itself as a child of the new parent element when the parent=() method is called" do
        s = Sequence.new("3006,0040")
        i = Item.new
        i.parent = s
        expect(s.children?).to eql true
      end

      it "should remove itself as a child of the old parent element when a new parent is set with the parent=() method" do
        s_old = Sequence.new("3006,0040")
        i = Item.new(:parent => s_old)
        s_new = Sequence.new("3006,0039")
        i.parent = s_new
        expect(s_old.children?).to be_falsey
      end

      it "should set a correct index value when an Item is added to a Sequence which is already occupied by several items" do
        s = Sequence.new("0008,0006")
        i1 = Item.new(:parent => s)
        i2 = Item.new(:parent => s)
        i = Item.new
        i.parent = s
        expect(i.index).to eql 2
      end

      it "should update the index attribute if an Item's index is changed by reordering the items in a Sequence" do
        s = Sequence.new("0008,0006")
        i1 = Item.new(:parent => s)
        i2 = Item.new(:parent => s)
        i = Item.new(:index => 1, :parent => s)
        expect(i.index).to eql 1
      end

      it "should pad the binary when the binary=() method is called with a string of odd length" do
        i = Item.new
        i.bin = "odd"
        expect(i.bin.length).to eql 4
      end

      it "should correctly set the length attribute when the binary=() method is called with a string of odd length" do
        i = Item.new
        i.bin = "odd"
        expect(i.length).to eql 4
      end

      it "should pad the binary when the Item is created with a binary of odd length" do
        i = Item.new(:bin => "odd")
        expect(i.bin.length).to eql 4
      end

      it "should raise an ArgumentError if the bin=() method is called with a non-string" do
        i = Item.new
        expect {i.bin = 42}.to raise_error(ArgumentError)
      end

      it "should correctly set the length attribute when the Item is created with a string of odd length" do
        i = Item.new(:bin => "odd")
        expect(i.length).to eql 4
      end

      it "should return an empty array when the parents method is called and no parent has been specified" do
        i = Item.new
        expect(i.parents).to eql Array.new
      end

      it "should return a 2-element array with the chain of parents, where the top parent is the last element, and immediate parent is the first" do
        dcm = DObject.new
        s = Sequence.new("3006,0039", :parent => dcm)
        i = Item.new(:parent => s)
        expect(i.parents.length).to eql 2
        expect(i.parents.first).to eql s
        expect(i.parents.last).to eql dcm
      end

      it "should return itself when the top_parent method is called and no external parent has been specified" do
        i = Item.new
        expect(i.top_parent).to eql i
      end

      it "should return the top parent in the chain of parents when the top_parent method is called on an element with multiple parents" do
        dcm = DObject.new
        s = Sequence.new("3006,0039", :parent => dcm)
        i = Item.new(:parent => s)
        expect(i.top_parent).to eql dcm
      end

      it "should return a Stream instance when the stream method is called" do
        i = Item.new
        expect(i.stream.class).to eq(Stream)
      end

      it "should use the name (supplied as an option), rather than the matching dictionary entry, on creation" do
        i = Item.new(:name => "Custom Item")
        expect(i.name).to eql "Custom Item"
      end

      it "should use the VR (supplied as an option), rather than the matching dictionary entry, on creation" do
        i = Item.new(:vr => "OB")
        expect(i.vr).to eql "OB"
      end

      it "should return false when the children? method is called as a newly created Item do not have child elements" do
        i = Item.new
        expect(i.children?).to be_falsey
      end

      it "should return true when the is_parent? method is called as a Item by definition is a parent" do
        i = Item.new
        expect(i.is_parent?).to eql true
      end

    end


    describe "#==" do

      it "should be true when comparing two instances having the same attribute values" do
        i1 = Item.new
        i2 = Item.new
        expect(i1 == i2).to be_truthy
      end

      it "should be false when comparing two instances having different attribute values (different children)" do
        i1 = Item.new
        i2 = Item.new
        i2.add(Sequence.new("0008,0006"))
        expect(i1 == i2).to be_falsey
      end

      it "should be false when comparing two instances having different attribute values (different vr but both no children)" do
        i1 = Item.new
        i2 = Item.new(:vr => "OB")
        expect(i1 == i2).to be_falsey
      end

      it "should be false when comparing against an instance of incompatible type" do
        i = Item.new
        expect(i == 42).to be_falsey
      end

    end


    describe "#eql?" do

      it "should be true when comparing two instances having the same attribute values" do
        i1 = Item.new
        i2 = Item.new
        expect(i1.eql?(i2)).to be_truthy
      end

      it "should be false when comparing two instances having different attribute values" do
        i1 = Item.new
        i2 = Item.new
        i2.add(Sequence.new("0008,0006"))
        expect(i1.eql?(i2)).to be_falsey
      end

    end


    describe "#hash" do

      it "should return the same Fixnum for two instances having the same attribute values" do
        i1 = Item.new
        i2 = Item.new
        expect(i1.hash).to eql i2.hash
      end

      it "should return a different Fixnum for two instances having different attribute values" do
        i1 = Item.new
        i2 = Item.new
        i2.add(Sequence.new("0008,0006"))
        expect(i1.hash).not_to eql i2.hash
      end

    end


    describe "#parse" do

      it "should parse and attach the data element" do
        bin = "\x0A\x30\x14\x00\x04\x00\x00\x00\x53\x49\x54\x45"
        i = Item.new
        i.parse(bin, '1.2.840.10008.1.2')
        expect(i.count).to eql 1
        expect(i.elements.length).to eql 1
        expect(i['300A,0014'].parent).to eql i
        expect(i.value('300A,0014')).to eql 'SITE'
      end

    end


    describe "#to_item" do

      it "should return itself" do
        i = Item.new
        expect(i.to_item.equal?(i)).to be_truthy
      end

    end

  end

end