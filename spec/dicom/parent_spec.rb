# encoding: UTF-8

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
        expect(dcm[id_tag]).to eql id
      end

      it "should return nil when a non-present tag is specified" do
        dcm = DObject.new
        name = Element.new("0010,0010", "John_Doe", :parent => dcm)
        expect(dcm["0010,0020"]).to be_nil
      end

      it "should return nil when called on an empty object" do
        dcm = DObject.new
        expect(dcm["0010,0020"]).to be_nil
      end

    end


    describe "#add" do

      it "should add a Element to the DICOM object" do
        dcm = DObject.new
        name_tag = "0010,0010"
        name = Element.new(name_tag, "John_Doe")
        dcm.add(name)
        expect(dcm[name_tag]).to eql name
      end

      it "should add a Sequence to the DICOM object" do
        dcm = DObject.new
        seq_tag = "0008,1140"
        seq = Sequence.new(seq_tag)
        dcm.add(seq)
        expect(dcm[seq_tag]).to eql seq
      end

      it "should have two children, when adding a Element and a Sequence to the empty DICOM object" do
        dcm = DObject.new
        seq = Sequence.new("0008,1140")
        dcm.add(seq)
        name = Element.new("0010,0010", "John_Doe")
        dcm.add(name)
        expect(dcm.count).to eql 2
      end

      it "should update the parent attribute of the Element when it is added to a parent" do
        dcm = DObject.new
        name = Element.new("0010,0010", "John_Doe")
        dcm.add(name)
        expect(name.parent).to eql dcm
      end

      it "should update the parent attribute of the Sequence when it is added to a parent" do
        dcm = DObject.new
        seq = Sequence.new("0008,1140")
        dcm.add(seq)
        expect(seq.parent).to eql dcm
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
        expect(@dcm["0008,1140"].children.first).to be_an(Item)
      end

      it "should add the Item specified as a parameter" do
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        expect(@dcm["0008,1140"].children.first).to eql item
      end

      it "should update the parent attribute of the Item when it is added to a parent" do
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        expect(item.parent).to eql @dcm["0008,1140"]
      end

      it "should set the parent attribute of the Item that is created when the method is used without an argument" do
        @dcm["0008,1140"].add_item
        expect(@dcm["0008,1140"].children.last.parent).to eql @dcm["0008,1140"]
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
        expect(@dcm["0008,1140"].children.first.index).to eql 0
      end

      it "should set the Item's index to one when it is added to a Sequence which already contains one Item" do
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        expect(item.index).to eql 1
      end

      it "should set the Item's index to one when it is specified with the :index option while being added to a Sequence which already contains two items" do
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item, :index => 1)
        expect(item.index).to eql 1
      end

      it "should set the Item's index one higher than the existing max index when a 'too big' :index option is used" do
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item, :index => 5)
        expect(item.index).to eql 1
      end

      it "should increase the following Item's index by one when an Item is placed in front of another Item by using the :index option" do
        @dcm["0008,1140"].add_item
        bumped_item = Item.new
        @dcm["0008,1140"].add_item(bumped_item)
        @dcm["0008,1140"].add_item(Item.new, :index => 1)
        expect(bumped_item.index).to eql 2
      end

      it "should use the expected index as key in the children's hash (when the :index option is not used)" do
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item)
        expect(@dcm["0008,1140"][1]).to eql item
      end

      it "should use the expected index as key in the children's hash (when the :index option is used)" do
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        item = Item.new
        @dcm["0008,1140"].add_item(item, :index => 1)
        expect(@dcm["0008,1140"][1]).to eql item
      end

    end


    describe "#children" do

      before :each do
        @dcm = DObject.new
      end

      it "should return an empty array when called on a parent with no children" do
        expect(@dcm.children).to be_an(Array)
        expect(@dcm.children.length).to eql 0
      end

      it "should return an array with length equal to the number of children connected to the parent" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Element.new("0010,0020", "12345"))
        expect(@dcm.children).to be_an(Array)
        expect(@dcm.children.length).to eql 2
      end

      it "should return an array where the child elements are sorted by tag" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        expect(@dcm.children.first.tag).to eql "0008,1140"
        expect(@dcm.children[1].tag).to eql "0010,0010"
        expect(@dcm.children.last.tag).to eql "0010,0030"
      end

      it "should return an array where the child elements are sorted by index when the parent is a Sequence" do
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        @dcm["0008,1140"].add_item
        expect(@dcm["0008,1140"].children.first.index).to eql 0
        expect(@dcm["0008,1140"].children[1].index).to eql 1
        expect(@dcm["0008,1140"].children.last.index).to eql 2
      end

    end


    describe "#children?" do

      before :each do
        @dcm = DObject.new
      end

      it "should return true when the parent has child elements" do
        @dcm.add(Sequence.new("0008,1140"))
        expect(@dcm.children?).to be_true
      end

      it "should return false on a child-less parent" do
        expect(@dcm.children?).to be_false
      end

      it "should return false on a parent who's children have been deleted" do
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.delete("0008,1140")
        expect(@dcm.children?).to be_false
      end

    end


    describe "#count" do

      before :each do
        @dcm = DObject.new
      end

      it "should return zero when the parent has no children" do
        expect(@dcm.count).to eql 0
      end

      it "should return an integer equal to the number of children added to this parent" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item # (this should not be counted as it is not a direct parent of dcm)
        expect(@dcm.count).to eql 3
      end

    end


    describe "#count_all" do

      before :each do
        @dcm = DObject.new
      end

      it "should return zero when the parent has no children" do
        expect(@dcm.count_all).to eql 0
      end

      it "should return an integer equal to the total number of children added to this parent and its child parents" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item # (this should be counted as we are now counting all sub-children)
        expect(@dcm.count_all).to eql 4
      end

    end


    describe "#exists?" do

      before :each do
        @dcm = DObject.new
      end

      it "should return false when the parent does not contain the queried element" do
        expect(@dcm.exists?("0010,0010")).to be_false
      end

      it "should return true when the parent contains the queried element" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        expect(@dcm.exists?("0010,0010")).to be_true
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
        expect(@dcm.group("0010")).to eql Array.new
      end

      it "should return an empty array when the parent contains only elements of other groups" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Sequence.new("0008,1140"))
        expect(@dcm.group("0020")).to eql Array.new
      end

      it "should return the elements that match the specified group" do
        match1 = Element.new("0010,0030", "20000101")
        match2 = Element.new("0010,0010", "John_Doe")
        @dcm.add(Sequence.new("0008,1140"))
        @dcm.add(match1)
        @dcm.add(match2)
        expect(@dcm.group("0010").length).to eql 2
        expect(@dcm.group("0010").include?(match1)).to be_true
        expect(@dcm.group("0010").include?(match2)).to be_true
      end

    end


    describe "#is_parent?" do

      it "should return true when called on a DObject" do
        expect(DObject.new.is_parent?).to be_true
      end

      it "should return true when called on a Sequence" do
        expect(Sequence.new("0008,1140").is_parent?).to be_true
      end

      it "should return true when called on an Item" do
        expect(Item.new.is_parent?).to be_true
      end

      it "should return false when called on a Element" do
        expect(Element.new("0010,0010", "John_Doe").is_parent?).to be_false
      end

    end


    describe "#length=()" do

      it "should raise an error when called on a DObject" do
        expect {DObject.new.length = 42}.to raise_error
      end

      it "should change the length attribute of the Sequence to the specified value" do
        s = Sequence.new("0008,1140")
        s.length = 42
        expect(s.length).to eql 42
      end

      it "should change the length attribute of the Item to the specified value" do
        i = Item.new
        i.length = 42
        expect(i.length).to eql 42
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
        expect(File.exist?(file)).to be_true
        f = File.new(file, "rb")
        line = f.gets
        expect(line.include?("John_Doe")).to be_true
        f.close
      end

      it "should cut off long Element values when the :value_max option is used" do
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        file = "#{TMPDIR}print.txt"
        @dcm.print(:file => file, :value_max => 4)
        f = File.new(file, "rb")
        line = f.gets
        expect(line.include?("John_Doe")).to be_false
        f.close
      end

      it "should return an Array" do
        @dcm.expects(:puts).at_least_once
        expect(@dcm.print).to be_an(Array)
      end

      it "should return an empty array when the parent has no children" do
        @dcm.expects(:puts).at_least_once
        expect(@dcm.print.length).to eql 0
      end

      it "should return an array of length equal to the number of children of the parent" do
        @dcm.add(Element.new("0010,0030", "20000101"))
        @dcm.add(Element.new("0010,0010", "John_Doe"))
        @dcm.add(Sequence.new("0008,1140"))
        @dcm["0008,1140"].add_item
        @dcm.expects(:puts).at_least_once
        expect(@dcm.print.length).to eql 4
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
        expect(@dcm.children.length).to eql @number_of_elements_before
      end

      it "should delete the Element when the tag is part of the parent's children" do
        @dcm.delete("0010,0030")
        expect(@dcm.exists?("0010,0030")).to be_false
        expect(@dcm.children.length).to eql @number_of_elements_before - 1
      end

      it "should delete the Sequence when the tag is part of the parent's children" do
        @dcm.delete("0008,1140")
        expect(@dcm.exists?("0008,1140")).to be_false
        expect(@dcm.children.length).to eql @number_of_elements_before - 1
      end

      it "should delete the Item from the parent Sequence" do
        @dcm["0008,1140"].delete(0)
        expect(@dcm["0008,1140"].exists?(1)).to be_false
        expect(@dcm["0008,1140"].children.length).to eql 0
      end

      it "should reset the parent reference from the Element when it is deleted" do
        @dcm.delete("0010,0030")
        expect(@d.parent).to be_nil
      end

      it "should reset the parent reference from the Sequence when it is deleted" do
        @dcm.delete("0008,1140")
        expect(@s.parent).to be_nil
      end

      it "should reset the parent reference from the Item when it is deleted" do
        @dcm["0008,1140"].delete(0)
        expect(@i.parent).to be_nil
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
        expect(dcm.children.length).to eql 0
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
        expect(dcm.children.length).to eql 2
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
        expect(dcm.children.length).to eql 2
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
        expect(dcm.count).to eql 3
        expect(dcm.count_all).to eql 4
        expect(dcm.exists?('0010,0010')).to be_true
        expect(dcm.exists?('5600,0020')).to be_true
        expect(dcm.exists?('0008,1140')).to be_true
        expect(dcm['0008,1140'][0].exists?('0008,0042')).to be_false
        expect(dcm.exists?('0008,0041')).to be_false
        expect(dcm.exists?('4008,0100')).to be_false
        expect(dcm.exists?('0008,1145')).to be_false
      end

    end


    describe "#representation" do

      it "should give 'DObject' when called on a DObject instance" do
        expect(DObject.new.representation).to eql 'DObject'
      end

      it "should give the item tag when called on an Item" do
        expect(Item.new.representation).to eql 'FFFE,E000'
      end

      it "should give the sequence tag when called on a Sequence" do
        tag = '300A,0010'
        expect(Sequence.new(tag).representation).to eql tag
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
        expect(@s.length).to eql -1
      end

      it "should set the length of the Item to -1 (UNDEFINED)" do
        @i.reset_length
        expect(@i.length).to eql -1
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
        expect(@dcm.value("1234,5678")).to be_nil
      end

      it "should return the expected string value from the Element" do
        expect(@dcm.value("0010,0010")).to eql "Anonymized"
      end

      it "should return a properly right-stripped string when the Element originally has had a string of odd length that has been padded" do
        expect(@dcm.value("0018,0022")).to eql "PFP"
      end

      it "should return the expected integer (unsigned short)" do
        expect(@dcm.value("0028,0010")).to eql 256
      end

      it "should return the numbers in a backslash separated string when the Element contains multiple numbers in its value field" do
        expect(@dcm.value("0018,1310")).to eql "0\\256\\208\\0"
      end

    end

  end

end