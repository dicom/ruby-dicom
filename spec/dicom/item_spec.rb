# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe Item do

    it "should set its name attribute as 'Item'" do
      i = Item.new
      i.name.should eql "Item"
    end

    it "should by default set its length attribute as -1, which really means 'Undefined'" do
      i = Item.new
      i.length.should eql -1
    end

    it "should use the :length option, if specified, to set the length attribute" do
      i = Item.new(:length => 30)
      i.length.should eql 30
    end

    it "should set the bin attribute as nil, as an Item, unless specified by option, doesn't have binary data" do
      i = Item.new
      i.bin.should be_nil
    end

    it "should set its VR attribute as '  '" do
      i = Item.new
      i.vr.should eql "  "
    end

    it "should set its tag attribute on creation" do
      i = Item.new
      i.tag.should eql "FFFE,E000"
    end

    it "should set its index attribute as nil when no parent or index is specified as options" do
      i = Item.new
      i.index.should be_nil
    end

    it "should not set its index if the :index option is specified but not the :parent option" do
      i = Item.new(:index => 2)
      i.index.should be_nil
    end

    it "should set its index if the :index option is specified along with a :parent option" do
      s = Sequence.new("0008,0006")
      i = Item.new(:index => 1, :parent => s)
      i.index.should eql 0
    end

    it "should set a correct index value when an Item is created with a reference to a Sequence which is already occupied by several items" do
      s = Sequence.new("0008,0006")
      i1 = Item.new(:parent => s)
      i2 = Item.new(:parent => s)
      i = Item.new(:parent => s)
      i.index.should eql 2
    end

    it "should set its parent attribute to nil when no parent is specified" do
      i = Item.new
      i.parent.should be_nil
    end

    it "should set the parent attribute when the :parent option is used on creation" do
      s = Sequence.new("0008,0006")
      i = Item.new(:parent => s)
      i.parent.should eql s
    end

    it "should update the parent attribute when the parent=() method is called" do
      s = Sequence.new("0008,0006")
      i = Item.new
      i.parent = s
      i.parent.should eql s
    end

    it "should register itself as a child of the new parent element when the parent=() method is called" do
      s = Sequence.new("3006,0040")
      i = Item.new
      i.parent = s
      s.children?.should eql true
    end

    it "should remove itself as a child of the old parent element when a new parent is set with the parent=() method" do
      s_old = Sequence.new("3006,0040")
      i = Item.new(:parent => s_old)
      s_new = Sequence.new("3006,0039")
      i.parent = s_new
      s_old.children?.should be_false
    end

    it "should set a correct index value when an Item is added to a Sequence which is already occupied by several items" do
      s = Sequence.new("0008,0006")
      i1 = Item.new(:parent => s)
      i2 = Item.new(:parent => s)
      i = Item.new
      i.parent = s
      i.index.should eql 2
    end

    it "should update the index attribute if an Item's index is changed by reordering the items in a Sequence" do
      s = Sequence.new("0008,0006")
      i1 = Item.new(:parent => s)
      i2 = Item.new(:parent => s)
      i = Item.new(:index => 1, :parent => s)
      i.index.should eql 1
    end

    it "should pad the binary when the binary=() method is called with a string of odd length" do
      i = Item.new
      i.bin = "odd"
      i.bin.length.should eql 4
    end

    it "should correctly set the length attribute when the binary=() method is called with a string of odd length" do
      i = Item.new
      i.bin = "odd"
      i.length.should eql 4
    end

    it "should pad the binary when the Item is created with a binary of odd length" do
      i = Item.new(:bin => "odd")
      i.bin.length.should eql 4
    end

    it "should raise an ArgumentError if the bin=() method is called with a non-string" do
      i = Item.new
      expect {i.bin = 42}.to raise_error(ArgumentError)
    end

    it "should correctly set the length attribute when the Item is created with a string of odd length" do
      i = Item.new(:bin => "odd")
      i.length.should eql 4
    end

    it "should return an empty array when the parents method is called and no parent has been specified" do
      i = Item.new
      i.parents.should eql Array.new
    end

    it "should return a 2-element array with the chain of parents, where the top parent is the last element, and immediate parent is the first" do
      obj = DObject.new
      s = Sequence.new("3006,0039", :parent => obj)
      i = Item.new(:parent => s)
      i.parents.length.should eql 2
      i.parents.first.should eql s
      i.parents.last.should eql obj
    end

    it "should return itself when the top_parent method is called and no external parent has been specified" do
      i = Item.new
      i.top_parent.should eql i
    end

    it "should return the top parent in the chain of parents when the top_parent method is called on an element with multiple parents" do
      obj = DObject.new
      s = Sequence.new("3006,0039", :parent => obj)
      i = Item.new(:parent => s)
      i.top_parent.should eql obj
    end

    it "should return a Stream instance when the stream method is called" do
      i = Item.new
      i.stream.class.should == Stream
    end

    it "should use the name (supplied as an option), rather than the matching dictionary entry, on creation" do
      i = Item.new(:name => "Custom Item")
      i.name.should eql "Custom Item"
    end

    it "should use the VR (supplied as an option), rather than the matching dictionary entry, on creation" do
      i = Item.new(:vr => "OB")
      i.vr.should eql "OB"
    end

    it "should return false when the children? method is called as a newly created Item do not have child elements" do
      i = Item.new
      i.children?.should be_false
    end

    it "should return true when the is_parent? method is called as a Item by definition is a parent" do
      i = Item.new
      i.is_parent?.should eql true
    end

  end

end