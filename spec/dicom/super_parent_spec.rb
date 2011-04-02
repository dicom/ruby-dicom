# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe SuperParent, "#[]" do

    it "should return the data element when the argument specifies a valid child element tag" do
      obj = DObject.new(nil, :verbose => false)
      id_tag = "0010,0020"
      name = DataElement.new("0010,0010", "John_Doe", :parent => obj)
      id = DataElement.new(id_tag, "12345", :parent => obj)
      birth = DataElement.new("0010,0030", "20000101", :parent => obj)
      obj[id_tag].should eql id
    end

    it "should return nil when a non-present tag is specified" do
      obj = DObject.new(nil, :verbose => false)
      name = DataElement.new("0010,0010", "John_Doe", :parent => obj)
      obj["0010,0020"].should be_nil
    end

    it "should return nil when called on an empty object" do
      obj = DObject.new(nil, :verbose => false)
      obj["0010,0020"].should be_nil
    end

  end


  describe SuperParent, "#add" do

    it "should add a DataElement to the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      name_tag = "0010,0010"
      name = DataElement.new(name_tag, "John_Doe")
      obj.add(name)
      obj[name_tag].should eql name
    end

    it "should add a Sequence to the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      seq_tag = "0008,1140"
      seq = Sequence.new(seq_tag)
      obj.add(seq)
      obj[seq_tag].should eql seq
    end

    it "should raise ArgumentError when it is called with an Item" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.add(Item.new)}.to raise_error(ArgumentError)
    end

    it "should raise an error when the it is called on a Sequence" do
      seq = Sequence.new("0008,1140")
      name = DataElement.new("0010,0010", "John_Doe")
      expect {seq.add(name)}.to raise_error
    end

  end


  describe SuperParent, "#add_item" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
      @obj.add(Sequence.new("0008,1140"))
    end

    it "should add an empty Item when it is called without a parameter" do
      @obj["0008,1140"].add_item
      @obj["0008,1140"].children.first.should be_an(Item)
    end

    it "should add the Item specified as a parameter" do
      item = Item.new
      @obj["0008,1140"].add_item(item)
      @obj["0008,1140"].children.first.should eql item
    end

    it "should raise ArgumentError if a non-positive integer is specified as an option" do
      expect {@obj["0008,1140"].add_item(Item.new, :index => -1)}.to raise_error(ArgumentError)
    end

    it "should raise an ArgumentError when it is called with a non-Item as parameter" do
      expect {@obj["0008,1140"].add_item(DataElement.new("0010,0010", "John_Doe"))}.to raise_error(ArgumentError)
    end

    it "should raise an error when an Item is attempted added to a DObject" do
      expect {@obj.add_item}.to raise_error
    end

    it "should set the Item's index to zero when it is added to an empty Sequence" do
      @obj["0008,1140"].add_item
      @obj["0008,1140"].children.first.index.should eql 0
    end

    it "should set the Item's index to one when it is added to a Sequence which already contains one Item" do
      @obj["0008,1140"].add_item
      item = Item.new
      @obj["0008,1140"].add_item(item)
      item.index.should eql 1
    end

    it "should set the Item's index to one when it is specified with the :index option while being added to a Sequence which already contains two items" do
      @obj["0008,1140"].add_item
      @obj["0008,1140"].add_item
      item = Item.new
      @obj["0008,1140"].add_item(item, :index => 1)
      item.index.should eql 1
    end

    it "should set the Item's index one higher than the existing max index when a 'too big' :index option is used" do
      @obj["0008,1140"].add_item
      item = Item.new
      @obj["0008,1140"].add_item(item, :index => 5)
      item.index.should eql 1
    end

    it "should increase the following Item's index by one when an Item is placed in front of another Item by using the :index option" do
      @obj["0008,1140"].add_item
      bumped_item = Item.new
      @obj["0008,1140"].add_item(bumped_item)
      @obj["0008,1140"].add_item(Item.new, :index => 1)
      bumped_item.index.should eql 2
    end

    it "should use the expected index as key in the children's hash (when the :index option is not used)" do
      @obj["0008,1140"].add_item
      item = Item.new
      @obj["0008,1140"].add_item(item)
      @obj["0008,1140"][1].should eql item
    end

    it "should use the expected index as key in the children's hash (when the :index option is used)" do
      @obj["0008,1140"].add_item
      @obj["0008,1140"].add_item
      item = Item.new
      @obj["0008,1140"].add_item(item, :index => 1)
      @obj["0008,1140"][1].should eql item
    end

  end


  describe SuperParent, "#children" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
    end

    it "should return an empty array when called on a parent with no children" do
      @obj.children.should be_an(Array)
      @obj.children.length.should eql 0
    end

    it "should return an array with length equal to the number of children connected to the parent" do
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.add(DataElement.new("0010,0020", "12345"))
      @obj.children.should be_an(Array)
      @obj.children.length.should eql 2
    end

    it "should return an array where the child elements are sorted by tag" do
      @obj.add(DataElement.new("0010,0030", "20000101"))
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.add(Sequence.new("0008,1140"))
      @obj.children.first.tag.should eql "0008,1140"
      @obj.children[1].tag.should eql "0010,0010"
      @obj.children.last.tag.should eql "0010,0030"
    end

    it "should return an array where the child elements are sorted by index when the parent is a Sequence" do
      @obj.add(Sequence.new("0008,1140"))
      @obj["0008,1140"].add_item
      @obj["0008,1140"].add_item
      @obj["0008,1140"].add_item
      @obj["0008,1140"].children.first.index.should eql 0
      @obj["0008,1140"].children[1].index.should eql 1
      @obj["0008,1140"].children.last.index.should eql 2
    end

  end


  describe SuperParent, "#children?" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
    end

    it "should return true when the parent has child elements" do
      @obj.add(Sequence.new("0008,1140"))
      @obj.children?.should be_true
    end

    it "should return false on a child-less parent" do
      @obj.children?.should be_false
    end

    it "should return false on a parent who's children have been removed" do
      @obj.add(Sequence.new("0008,1140"))
      @obj.remove("0008,1140")
      @obj.children?.should be_false
    end

  end


  describe SuperParent, "#count" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
    end

    it "should return zero when the parent has no children" do
      @obj.count.should eql 0
    end

    it "should return an integer equal to the number of children added to this parent" do
      @obj.add(DataElement.new("0010,0030", "20000101"))
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.add(Sequence.new("0008,1140"))
      @obj["0008,1140"].add_item # (this should not be counted as it is not a direct parent of obj)
      @obj.count.should eql 3
    end

  end


  describe SuperParent, "#count_all" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
    end

    it "should return zero when the parent has no children" do
      @obj.count_all.should eql 0
    end

    it "should return an integer equal to the total number of children added to this parent and its child parents" do
      @obj.add(DataElement.new("0010,0030", "20000101"))
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.add(Sequence.new("0008,1140"))
      @obj["0008,1140"].add_item # (this should be counted as we are now counting all sub-children)
      @obj.count_all.should eql 4
    end

  end


  describe SuperParent, "#exists?" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
    end

    it "should return false when the parent does not contain the queried element" do
      @obj.exists?("0010,0010").should be_false
    end

    it "should return true when the parent contains the queried element" do
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.exists?("0010,0010").should be_true
    end

  end


  describe SuperParent, "#group" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
    end

    it "should raise ArgumentError when a non-string argument is used" do
      expect {@obj.group(true)}.to raise_error(ArgumentError)
    end

    it "should return an empty array when called on an empty parent" do
      @obj.group("0010").should eql Array.new
    end

    it "should return an empty array when the parent contains only elements of other groups" do
      @obj.add(DataElement.new("0010,0030", "20000101"))
      @obj.add(Sequence.new("0008,1140"))
      @obj.group("0020").should eql Array.new
    end

    it "should return the elements that match the specified group" do
      match1 = DataElement.new("0010,0030", "20000101")
      match2 = DataElement.new("0010,0010", "John_Doe")
      @obj.add(Sequence.new("0008,1140"))
      @obj.add(match1)
      @obj.add(match2)
      @obj.group("0010").length.should eql 2
      @obj.group("0010").include?(match1).should be_true
      @obj.group("0010").include?(match2).should be_true
    end

  end


  describe SuperParent, "#is_parent?" do

    it "should return true when called on a DObject" do
      DObject.new(nil, :verbose => false).is_parent?.should be_true
    end

    it "should return true when called on a Sequence" do
      Sequence.new("0008,1140").is_parent?.should be_true
    end

    it "should return true when called on an Item" do
      Item.new.is_parent?.should be_true
    end

    it "should return false when called on a DataElement" do
      DataElement.new("0010,0010", "John_Doe").is_parent?.should be_false
    end

  end


  describe SuperParent, "#length=()" do

    it "should raise an error when called on a DObject" do
      expect {DObject.new(nil, :verbose => false).length = 42}.to raise_error
    end

    it "should change the length attribute of the Sequence to the specified value" do
      s = Sequence.new("0008,1140")
      s.length = 42
      s.length.should eql 42
    end

    it "should change the length attribute of the Item to the specified value" do
      i = Item.new
      i.length = 42
      i.length.should eql 42
    end

  end


  # FIXME? Currently there is no specification for the format of the element printout: alignment, tree-visualization, content, etc.
  #
  describe SuperParent, "#print" do

    before :each do
      @obj = DObject.new(nil, :verbose => false)
    end

    it "should print a notice to the screen when run on an empty parent" do
      @obj.expects(:puts).at_least_once
      @obj.print
    end

    it "should print element information to the screen" do
      @obj.add(DataElement.new("0010,0030", "20000101"))
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.add(Sequence.new("0008,1140"))
      @obj.expects(:puts).at_least_once
      @obj.print
    end

    it "should not print to the screen when the :file parameter is used" do
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.expects(:puts).never
      @obj.print(:file => "#{TMPDIR}print.txt")
    end

    it "should create a file and fill it with the tag information when the :file parameter is used" do
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      file = "#{TMPDIR}print.txt"
      @obj.print(:file => file)
      File.exist?(file).should be_true
      f = File.new(file, "rb")
      line = f.gets
      line.include?("John_Doe").should be_true
      f.close
    end

    it "should cut off long DataElement values when the :value_max option is used" do
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      file = "#{TMPDIR}print.txt"
      @obj.print(:file => file, :value_max => 4)
      f = File.new(file, "rb")
      line = f.gets
      line.include?("John_Doe").should be_false
      f.close
    end

    it "should return an Array" do
      @obj.expects(:puts).at_least_once
      @obj.print.should be_an(Array)
    end

    it "should return an empty array when the parent has no children" do
      @obj.expects(:puts).at_least_once
      @obj.print.length.should eql 0
    end

    it "should return an array of length equal to the number of children of the parent" do
      @obj.add(DataElement.new("0010,0030", "20000101"))
      @obj.add(DataElement.new("0010,0010", "John_Doe"))
      @obj.add(Sequence.new("0008,1140"))
      @obj["0008,1140"].add_item
      @obj.expects(:puts).at_least_once
      @obj.print.length.should eql 4
    end

  end

end