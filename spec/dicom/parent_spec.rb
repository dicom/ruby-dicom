# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe Parent do

    describe "#[]" do

      it "should return the data element when the argument specifies a valid child element tag" do
        dcm = DObject.new
        id_tag = "0010,0020"
        name = Element.new("0010,0010", "John_Doe", :parent => dcm)
        id = Element.new(id_tag, "12345", :parent => dcm)
        birth = Element.new("0010,0030", "20000101", :parent => dcm)
        dcm[id_tag].should eql id
      end

      it "should return nil when a non-present tag is specified" do
        dcm = DObject.new
        name = Element.new("0010,0010", "John_Doe", :parent => dcm)
        dcm["0010,0020"].should be_nil
      end

      it "should return nil when called on an empty object" do
        dcm = DObject.new
        dcm["0010,0020"].should be_nil
      end

    end


    describe "#add" do

      it "should add a Element to the DICOM object" do
        dcm = DObject.new
        name_tag = "0010,0010"
        name = Element.new(name_tag, "John_Doe")
        dcm.add(name)
        dcm[name_tag].should eql name
      end

      it "should add a Sequence to the DICOM object" do
        dcm = DObject.new
        seq_tag = "0008,1140"
        seq = Sequence.new(seq_tag)
        dcm.add(seq)
        dcm[seq_tag].should eql seq
      end

      it "should have two children, when adding a Element and a Sequence to the empty DICOM object" do
        dcm = DObject.new
        seq = Sequence.new("0008,1140")
        dcm.add(seq)
        name = Element.new("0010,0010", "John_Doe")
        dcm.add(name)
        dcm.count.should eql 2
      end

      it "should update the parent attribute of the Element when it is added to a parent" do
        dcm = DObject.new
        name = Element.new("0010,0010", "John_Doe")
        dcm.add(name)
        name.parent.should eql dcm
      end

      it "should update the parent attribute of the Sequence when it is added to a parent" do
        dcm = DObject.new
        seq = Sequence.new("0008,1140")
        dcm.add(seq)
        seq.parent.should eql dcm
      end

      it "should raise ArgumentError when it is called with an Item" do
        dcm = DObject.new
        expect {dcm.add(Item.new)}.to raise_error(ArgumentError)
      end

      it "should raise an error when the it is called on a Sequence with an Element argument" do
        seq = Sequence.new("0008,1140")
        name = Element.new("0010,0010", "John_Doe")
        expect {seq.add(name)}.to raise_error
      end

# It should be possible to add Data Set Trailing Padding elements anywhere in a DICOM file, but
# this requires some deeper changes to the library, so we'll keep the tests on hold until a
# clever implementation has been thought out:
=begin
      it "should allow the special Data Set Trailing Padding Element to be added to a Sequence" do
        seq = Sequence.new('0008,1140')
        padding = Element.new('FFFC,FFFC', 0)
        seq.add(padding)
        seq.exists?('FFFC,FFFC').should be_true
        seq.children.length.should eql 1
        seq['FFFC,FFFC'].should eql padding
      end
=end

    end


    describe "#add_item" do

      before :each do
        @dcm = DObject.new
        @dcm.add(Sequence.new("0008,1140"))
      end

      it "should add an empty Item when it is called without a parameter" do
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].children.first.should be_an(Item)
      end

      it "should add the Item specified as a parameter" do
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        @dcm["0008,1140"].children.first.should eql item
      end

      it "should update the parent attribute of the Item when it is added to a parent" do
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        item.parent.should eql @dcm["0008,1140"]
      end

      it "should set the parent attribute of the Item that is created when the method is used without an argument" do
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].children.last.parent.should eql @dcm["0008,1140"]
      end

      it "should raise ArgumentError if a non-positive integer is specified as an option" do
        expect {@dcm["0008,1140"].add_item(Item.new, :index => -1)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when it is called with a non-Item as parameter" do
        expect {@dcm["0008,1140"].add_item(Element.new("0010,0010", "John_Doe"))}.to raise_error(ArgumentError)
      end

      it "should raise an error when an Item is attempted added to a DObject" do
        expect {@dcm.add_item}.to raise_error
      end

      it "should set the Item's index to zero when it is added to an empty Sequence" do
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].children.first.index.should eql 0
      end

      it "should set the Item's index to one when it is added to a Sequence which already contains one Item" do
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        item.index.should eql 1
      end

      it "should set the Item's index to one when it is specified with the :index option while being added to a Sequence which already contains two items" do
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item, :index => 1)
        item.index.should eql 1
      end

      it "should set the Item's index one higher than the existing max index when a 'too big' :index option is used" do
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item, :index => 5)
        item.index.should eql 1
      end

      it "should increase the following Item's index by one when an Item is placed in front of another Item by using the :index option" do
        @dcm["0008,1140"].add_item
        bumped_item = Item.new
        @dcm["0008,1140"].add_item(bumped_item)
        @dcm["0008,1140"].add_item(Item.new, :index => 1)
        bumped_item.index.should eql 2
      end

      it "should use the expected index as key in the children's hash (when the :index option is not used)" do
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        @dcm["0008,1140"][1].should eql item
      end

      it "should use the expected index as key in the children's hash (when the :index option is used)" do
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item, :index => 1)
        @dcm["0008,1140"][1].should eql item
      end

    end


    describe "#children" do

      before :each do
        @dcm = DObject.new
      end

      it "should return an empty array when called on a parent with no children" do
        @dcm.children.should be_an(Array)
        @dcm.children.length.should eql 0
      end

      it "should return an array with length equal to the number of children connected to the parent" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Element.new("0010,0020", "12345"))
        @dcm.children.should be_an(Array)
        @dcm.children.length.should eql 2
      end

      it "should return an array where the child elements are sorted by tag" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.children.first.tag.should eql "0008,1140"
        @dcm.children[1].tag.should eql "0010,0010"
        @dcm.children.last.tag.should eql "0010,0030"
      end

      it "should return an array where the child elements are sorted by index when the parent is a Sequence" do
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].children.first.index.should eql 0
        @dcm["0008,1140"].children[1].index.should eql 1
        @dcm["0008,1140"].children.last.index.should eql 2
      end

    end


    describe "#children?" do

      before :each do
        @dcm = DObject.new
      end

      it "should return true when the parent has child elements" do
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.children?.should be_true
      end

      it "should return false on a child-less parent" do
        @dcm.children?.should be_false
      end

      it "should return false on a parent who's children have been deleted" do
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.delete("0008,1140")
        @dcm.children?.should be_false
      end

    end


    describe "#count" do

      before :each do
        @dcm = DObject.new
      end

      it "should return zero when the parent has no children" do
        @dcm.count.should eql 0
      end

      it "should return an integer equal to the number of children added to this parent" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item # (this should not be counted as it is not a direct parent of dcm)
        @dcm.count.should eql 3
      end

    end


    describe "#count_all" do

      before :each do
        @dcm = DObject.new
      end

      it "should return zero when the parent has no children" do
        @dcm.count_all.should eql 0
      end

      it "should return an integer equal to the total number of children added to this parent and its child parents" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item # (this should be counted as we are now counting all sub-children)
        @dcm.count_all.should eql 4
      end

    end


    describe "#exists?" do

      before :each do
        @dcm = DObject.new
      end

      it "should return false when the parent does not contain the queried element" do
        @dcm.exists?("0010,0010").should be_false
      end

      it "should return true when the parent contains the queried element" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.exists?("0010,0010").should be_true
      end

    end


    describe "#group" do

      before :each do
        @dcm = DObject.new
      end

      it "should raise ArgumentError when a non-string argument is used" do
        expect {@dcm.group(true)}.to raise_error(ArgumentError)
      end

      it "should return an empty array when called on an empty parent" do
        @dcm.group("0010").should eql Array.new
      end

      it "should return an empty array when the parent contains only elements of other groups" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.group("0020").should eql Array.new
      end

      it "should return the elements that match the specified group" do
        match1 = Element.new("0010,0030", "20000101")
        match2 = Element.new("0010,0010", "John_Doe")
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.add(match1)
        @dcm.add(match2)
        @dcm.group("0010").length.should eql 2
        @dcm.group("0010").include?(match1).should be_true
        @dcm.group("0010").include?(match2).should be_true
      end

    end


    describe "#is_parent?" do

      it "should return true when called on a DObject" do
        DObject.new.is_parent?.should be_true
      end

      it "should return true when called on a Sequence" do
        Sequence.new("0008,1140").is_parent?.should be_true
      end

      it "should return true when called on an Item" do
        Item.new.is_parent?.should be_true
      end

      it "should return false when called on a Element" do
        Element.new("0010,0010", "John_Doe").is_parent?.should be_false
      end

    end


    describe "#length=()" do

      it "should raise an error when called on a DObject" do
        expect {DObject.new.length = 42}.to raise_error
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
    describe "#print" do

      before :each do
        @dcm = DObject.new
      end

      it "should print a notice to the screen when run on an empty parent" do
        @dcm.expects(:puts).at_least_once
        @dcm.print
      end

      it "should print element information to the screen" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.expects(:puts).at_least_once
        @dcm.print
      end

      it "should not print to the screen when the :file parameter is used" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.expects(:puts).never
        @dcm.print(:file => "#{TMPDIR}print.txt")
      end

      it "should create a file and fill it with the tag information when the :file parameter is used" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        file = "#{TMPDIR}print.txt"
        @dcm.print(:file => file)
        File.exist?(file).should be_true
        f = File.new(file, "rb")
        line = f.gets
        line.include?("John_Doe").should be_true
        f.close
      end

      it "should cut off long Element values when the :value_max option is used" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        file = "#{TMPDIR}print.txt"
        @dcm.print(:file => file, :value_max => 4)
        f = File.new(file, "rb")
        line = f.gets
        line.include?("John_Doe").should be_false
        f.close
      end

      it "should return an Array" do
        @dcm.expects(:puts).at_least_once
        @dcm.print.should be_an(Array)
      end

      it "should return an empty array when the parent has no children" do
        @dcm.expects(:puts).at_least_once
        @dcm.print.length.should eql 0
      end

      it "should return an array of length equal to the number of children of the parent" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item
        @dcm.expects(:puts).at_least_once
        @dcm.print.length.should eql 4
      end

    end


    describe "#delete" do

      before :each do
        @dcm = DObject.new
        @d = Element.new("0010,0030", "20000101")
        @s = Sequence.new("0008,1140")
        @i = Item.new
        @dcm.add(@d)
        @dcm.add(@s)
        @dcm["0008,1140"].add_item(@i)
        @number_of_elements_before = @dcm.children.length
      end

      it "should raise ArgumentError when the argument is not a string or integer" do
        expect {@dcm.delete(3.55)}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when the argument is not a valid tag" do
        expect {@dcm.delete("asdf,asdf")}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when the argument is a negative integer" do
        expect {@dcm.delete(-1)}.to raise_error(ArgumentError)
      end

      it "should not delete any elements when the specified tag is not part of the parent's children" do
        @dcm.delete("0010,0013")
        @dcm.children.length.should eql @number_of_elements_before
      end

      it "should delete the Element when the tag is part of the parent's children" do
        @dcm.delete("0010,0030")
        @dcm.exists?("0010,0030").should be_false
        @dcm.children.length.should eql @number_of_elements_before - 1
      end

      it "should delete the Sequence when the tag is part of the parent's children" do
        @dcm.delete("0008,1140")
        @dcm.exists?("0008,1140").should be_false
        @dcm.children.length.should eql @number_of_elements_before - 1
      end

      it "should delete the Item from the parent Sequence" do
        @dcm["0008,1140"].delete(0)
        @dcm["0008,1140"].exists?(1).should be_false
        @dcm["0008,1140"].children.length.should eql 0
      end

      it "should reset the parent reference from the Element when it is deleted" do
        @dcm.delete("0010,0030")
        @d.parent.should be_nil
      end

      it "should reset the parent reference from the Sequence when it is deleted" do
        @dcm.delete("0008,1140")
        @s.parent.should be_nil
      end

      it "should reset the parent reference from the Item when it is deleted" do
        @dcm["0008,1140"].delete(0)
        @i.parent.should be_nil
      end

    end


    describe "#delete_children" do

      it "should delete all children from the parent element" do
        dcm = DObject.new
        dcm.add(Element.new("0010,0030", "20000101"))
        dcm.add(Element.new("0011,0030", "42"))
        dcm.add(Element.new("0010,0010", "John_Doe"))
        dcm.add(Element.new("0010,0020", "12345"))
        dcm.add(Sequence.new("0008,1140"))
        dcm["0008,1140"].add_item
        dcm.delete_children
        dcm.children.length.should eql 0
      end

    end


    describe "#delete_group" do

      it "should delete all children from the parent element" do
        dcm = DObject.new
        dcm.add(Element.new("0010,0030", "20000101"))
        dcm.add(Element.new("0011,0030", "42"))
        dcm.add(Element.new("0010,0010", "John_Doe"))
        dcm.add(Element.new("0010,0020", "12345"))
        dcm.add(Sequence.new("0008,1140"))
        dcm["0008,1140"].add_item
        dcm.delete_group("0010")
        dcm.children.length.should eql 2
      end

    end


    describe "#delete_private" do

      it "should delete all private child elements from the parent element" do
        dcm = DObject.new
        dcm.add(Element.new("0010,0030", "20000101"))
        dcm.add(Element.new("0011,0030", "42"))
        dcm.add(Element.new("0013,0010", "John_Doe"))
        dcm.add(Element.new("0015,0020", "12345"))
        dcm.add(Sequence.new("0008,1140"))
        dcm["0008,1140"].add_item
        dcm.delete_private
        dcm.children.length.should eql 2
      end

    end


    describe "#delete_retired" do

      it "should delete all retired child elements from the parent element" do
        dcm = DObject.new
        dcm.add(Element.new('0010,0010', 'Name'))
        dcm.add(Element.new('5600,0020', '42'))
        dcm.add(Element.new('0008,0041', 'Ret')) # Retired
        dcm.add(Element.new('4008,0100', '20010101')) # Retired
        dcm.add(Sequence.new('0008,1140'))
        dcm['0008,1140'].add_item
        dcm['0008,1140'][0].add(Element.new('0008,0042', '131-I')) # Retired
        dcm.add(Sequence.new('0008,1145')) # Retired
        dcm['0008,1145'].add_item
        dcm['0008,1145'][0].add(Element.new('0008,0070', 'ACME'))
        dcm.delete_retired
        dcm.count.should eql 3
        dcm.count_all.should eql 4
        dcm.exists?('0010,0010').should be_true
        dcm.exists?('5600,0020').should be_true
        dcm.exists?('0008,1140').should be_true
        dcm['0008,1140'][0].exists?('0008,0042').should be_false
        dcm.exists?('0008,0041').should be_false
        dcm.exists?('4008,0100').should be_false
        dcm.exists?('0008,1145').should be_false
      end

    end


    describe "#reset_length" do

      before :each do
        @dcm = DObject.new
        @s = Sequence.new("0008,1140", :parent => @dcm)
        @i = Item.new(:parent => @s)
        @s.length, @i.length = 42, 42
      end

      it "should raise an error when the method is executed on a DObject" do
        expect {@dcm.reset_length}.to raise_error
      end

      it "should set the length of the Sequence to -1 (UNDEFINED)" do
        @s.reset_length
        @s.length.should eql -1
      end

      it "should set the length of the Item to -1 (UNDEFINED)" do
        @i.reset_length
        @i.length.should eql -1
      end

    end


    describe "#value" do

      before :each do
        @dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      end

      it "should raise ArgumentError when the argument is not a string or integer" do
        expect {@dcm.value(3.55)}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when the argument is not a valid tag" do
        expect {@dcm.value("asdf,asdf")}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when the argument is a negative integer" do
        expect {@dcm.value(-1)}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when the argument is a Sequence (as parent elements by our definition don't have a value)" do
        expect {@dcm.value("0008,1140")}.to raise_error(ArgumentError)
      end

      it "should raise ArgumentError when the argument is an Item (as parent elements by our definition don't have a value)" do
        expect {@dcm["0008,1140"].value(0)}.to raise_error(ArgumentError)
      end

      it "should return nil when the specified tag is not part of the parent's children" do
        @dcm.value("1234,5678").should be_nil
      end

      it "should return the expected string value from the Element" do
        @dcm.value("0010,0010").should eql "Anonymized"
      end

      it "should return a properly right-stripped string when the Element originally has had a string of odd length that has been padded" do
        @dcm.value("0018,0022").should eql "PFP"
      end

      it "should return the expected integer (unsigned short)" do
        @dcm.value("0028,0010").should eql 256
      end

      it "should return the numbers in a backslash separated string when the Element contains multiple numbers in its value field" do
        @dcm.value("0018,1310").should eql "0\\256\\208\\0"
      end

    end

  end

end