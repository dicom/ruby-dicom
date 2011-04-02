# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe Sequence do
    
    it "should raise ArgumentError when creation is attempted with an invalid tag string" do
      expect {Sequence.new("asdf,asdf")}.to raise_error(ArgumentError)
    end
    
    it "should raise ArgumentError when creation is attempted with a non-string as tag" do
      expect {Sequence.new(3.1337)}.to raise_error(ArgumentError)
    end
    
    it "should get its name attribute from the dictionary on creation" do
      s = Sequence.new("0008,0006")
      s.name.should eql "Language Code Sequence"
    end
    
    it "should by default set its length attribute as -1, which really means 'Undefined'" do
      s = Sequence.new("0008,0006")
      s.length.should eql -1
    end
    
    it "should use the :length option, if specified, to set the length attribute" do
      s = Sequence.new("0008,0006", :length => 30)
      s.length.should eql 30
    end
    
    it "should set the bin attribute as nil, as a Sequence, by our definition, doesn't have binary data" do
      s = Sequence.new("0008,0006")
      s.bin.should be_nil
    end
    
    it "should get its VR attribute from the dictionary on creation" do
      s = Sequence.new("0008,0006")
      s.vr.should eql "SQ"
    end
    
    it "should set its tag attribute on creation" do
      s = Sequence.new("0008,0006")
      s.tag.should eql "0008,0006"
    end
    
    it "should set its parent attribute to nil when no parent is specified" do
      s = Sequence.new("0008,0006")
      s.parent.should be_nil
    end
    
    it "should set the parent attribute when the :parent option is used on creation" do
      i = Item.new
      s = Sequence.new("0008,0006", :parent => i)
      s.parent.should eql i
    end
    
    it "should update the parent attribute when the parent=() method is called" do
      i = Item.new
      s = Sequence.new("0008,0006")
      s.parent = i
      s.parent.should eql i
    end
    
=begin # Fails, should be looked at some time...
    it "should register itself as a child of the new parent element when the parent=() method is called" do
      i = Item.new
      s = Sequence.new("3006,0040")
      s.parent = i
      i.children?.should eql true
    end
=end
    
    it "should remove itself as a child of the old parent element when a new parent is set with the parent=() method" do
      i_old = Item.new
      s = Sequence.new("3006,0040", :parent => i_old)
      i_new = Item.new
      s.parent = i_new
      i_old.children?.should be_false
    end
    
    it "should return an empty array when the parents method is called and no parent has been specified" do
      s = Sequence.new("0008,0006")
      s.parents.should eql Array.new
    end
    
    it "should return a 3-element array with the chain of parents, where the top parent is the last element, and immediate parent is the first" do
      obj = DObject.new(nil, :verbose => false)
      s1 = Sequence.new("3006,0039", :parent => obj)
      i = Item.new(:parent => s1)
      s2 = Sequence.new("3006,0040", :parent => i)
      s2.parents.length.should eql 3
      s2.parents.first.should eql i
      s2.parents.last.should eql obj
    end
    
    it "should return itself when the top_parent method is called and no external parent has been specified" do
      s = Sequence.new("0008,0006")
      s.top_parent.should eql s
    end
    
    it "should return the top parent in the chain of parents when the top_parent method is called on an element with multiple parents" do
      obj = DObject.new(nil, :verbose => false)
      s1 = Sequence.new("3006,0039", :parent => obj)
      i = Item.new(:parent => s1)
      s2 = Sequence.new("3006,0040", :parent => i)
      s2.top_parent.should eql obj
    end
    
    it "should return a Stream instance when the stream method is called" do
      s = Sequence.new("0008,0006")
      s.stream.class.should == Stream
    end
    
    it "should use the name (supplied as an option), rather than the matching dictionary entry, on creation" do
      s = Sequence.new("0008,0006", :name => "Custom Sequence")
      s.name.should eql "Custom Sequence"
    end
    
    it "should use the VR (supplied as an option), rather than the matching dictionary entry, on creation" do
      s = Sequence.new("0008,0006", :vr => "OB")
      s.vr.should eql "OB"
    end
    
    it "should set the name attribute as 'Private' when a private tag is created" do
      s = Sequence.new("0029,0010", :vr => "UL")
      s.name.should eql "Private"
    end
    
    it "should set the name attribute as 'Unknown' when a non-private tag is created that can't be matched in the dictionary" do
      s = Sequence.new("ABF0,1234")
      s.name.should eql "Unknown"
    end
    
    it "should return false when the children? method is called as a newly created Sequence do not have child elements" do
      s = Sequence.new("0008,0006")
      s.children?.should be_false
    end
    
    it "should return true when the is_parent? method is called as a Sequence by definition is a parent" do
      s = Sequence.new("0008,0006")
      s.is_parent?.should eql true
    end
    
  end

end