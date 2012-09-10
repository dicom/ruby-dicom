# encoding: ASCII-8BIT

require 'spec_helper'

module DICOM

  describe DLibrary do

    context "#add_element_dictionary" do

      it "should add this dictionary to ruby-dicom's element dictionary" do
        LIBRARY.add_element_dictionary(DICT_ELEMENTS)
        e1 = LIBRARY.element('0009,010C')
        e1.name.should eql 'World Domination Scheme UID'
        e1.vr.should eql 'UI'
        e1.vm.should eql '1'
        e1.retired?.should be_false
        e2 = LIBRARY.element('2027,010F')
        e2.name.should eql 'Code Smell Context Identifier'
        e2.vr.should eql 'CS'
        e2.vm.should eql '1'
        e2.retired?.should be_true
        e3 = LIBRARY.element('AAAB,0110')
        e3.name.should eql 'Github Commit Sequence'
        e3.vr.should eql 'SQ'
        e3.vm.should eql '1'
        e3.retired?.should be_false
        e4 = LIBRARY.element('FFFF,0112')
        e4.name.should eql 'Bug Registry'
        e4.vr.should eql 'UL'
        e4.vm.should eql '1-n'
        e4.retired?.should be_false
      end

    end


    context "#element" do

      it "should return the matching DictionaryElement" do
        tag = '0010,0010'
        element = LIBRARY.element(tag)
        element.should be_a DictionaryElement
        element.tag.should eql tag
        element.retired?.should be_false
      end

      it "should return the matching (retired) DictionaryElement" do
        tag = '0000,51B0' # Retired
        element = LIBRARY.element(tag)
        element.should be_a DictionaryElement
        element.tag.should eql tag
        element.retired?.should be_true
      end

      it "should create a 'group length element' when given a group length type tag" do
        element = LIBRARY.element('0010,0000')
        element.name.should eql 'Group Length'
        element.vr.should eql 'UL'
        element.retired?.should be_false
      end

      it "should create a 'group length element' when given a private group length type tag" do
        element = LIBRARY.element('0011,0000')
        element.name.should eql 'Group Length'
        element.vr.should eql 'UL'
        element.retired?.should be_false
      end

      it "should create a 'private element' when given a private type tag" do
        element = LIBRARY.element('0011,ABCD')
        element.name.should eql 'Private'
        element.vr.should eql 'UN'
        element.retired?.should be_false
      end

      it "should create an 'unknown element' when no match is made" do
        element = LIBRARY.element('EEEE,ABCD')
        element.name.should eql 'Unknown'
        element.vr.should eql 'UN'
        element.retired?.should be_false
      end

      it "should give the expected name when it contains an apostrophe" do
        tag = '0010,0010'
        element = LIBRARY.element(tag)
        element.name.should eql "Patient's Name"
      end

    end


    context "#name_and_vr [Command Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0000,0000')
        name.should eql 'Command Group Length'
        vr.should eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0000,1005')
        name.should eql 'Attribute Identifier List'
        vr.should eql 'AT'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0000,51B0') # Retired command element
        name.should eql 'Overlays'
        vr.should eql 'US'
      end

    end


    context "#name_and_vr [File Meta Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0002,0000')
        name.should eql 'File Meta Information Group Length'
        vr.should eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0002,0010')
        name.should eql 'Transfer Syntax UID'
        vr.should eql 'UI'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0002,0102')
        name.should eql 'Private Information'
        vr.should eql 'OB'
      end

    end


    context "#name_and_vr [Directory Structuring Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0004,1130')
        name.should eql 'File-set ID'
        vr.should eql 'CS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0004,1220')
        name.should eql 'Directory Record Sequence'
        vr.should eql 'SQ'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0004,1600')
        name.should eql 'Number of References'
        vr.should eql 'UL'
      end

    end


    context "#name_and_vr [Data Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0001')
        name.should eql 'Length to End'
        vr.should eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0018')
        name.should eql 'SOP Instance UID'
        vr.should eql 'UI'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0034')
        name.should eql 'Overlay Time'
        vr.should eql 'TM'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0018,9511')
        name.should eql 'Secondary Positioner Scan Start Angle'
        vr.should eql 'FL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0054,0039')
        name.should eql 'Phase Description'
        vr.should eql 'CS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('3002,0022')
        name.should eql 'Radiation Machine SAD'
        vr.should eql 'DS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0014,4056') # New tag in the 2011 edition
        name.should eql 'Coupling Medium'
        vr.should eql 'ST'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0028,0453') # (0028,04x3)
        name.should eql 'Coefficient Coding Pointers'
        vr.should eql 'AT'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0028,08A8') # (0028,08x8)
        name.should eql 'Image Data Location'
        vr.should eql 'AT'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1000,ABC0') # (1000,xxx0)
        name.should eql 'Escape Triplet'
        vr.should eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1000,DEF5') # (1000,xxx5)
        name.should eql 'Shift Table Triplet'
        vr.should eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1010,1234') # (1010,xxxx)
        name.should eql 'Zonal Map'
        vr.should eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('5012,2600') # (50xx,2600)
        name.should eql 'Curve Referenced Overlay Sequence'
        vr.should eql 'SQ'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('60CC,0011') # (60xx,0011)
        name.should eql 'Overlay Columns'
        vr.should eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('60EE,0110') # (60xx,0110)
        name.should eql 'Overlay Format'
        vr.should eql 'CS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('7FAA,0020') # (7Fxx,0020)
        name.should eql 'Variable Coefficients SDVN'
        vr.should eql 'OW'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('7FE0,0010')
        name.should eql 'Pixel Data'
        vr.should eql 'OW' # (OW or OB)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('FFFE,E000')
        name.should eql 'Item'
        vr.should eql '  ' # (not defined)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('FFFE,E00D')
        name.should eql 'Item Delimitation Item'
        vr.should eql '  ' # (not defined)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('FFFE,E0DD')
        name.should eql 'Sequence Delimitation Item'
        vr.should eql '  ' # (not defined)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0000') # (Group Length)
        name.should eql 'Group Length'
        vr.should eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('7FE0,0000') # (Group Length)
        name.should eql 'Group Length'
        vr.should eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1111,0000') # (Private Group Length)
        name.should eql 'Group Length'
        vr.should eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('AAAA,FFFF') # (An undefined, but not private tag)
        name.should eql 'Unknown'
        vr.should eql 'UN'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1111,2222') # (A private tag)
        name.should eql 'Private'
        vr.should eql 'UN'
      end

    end


    context "#uid" do

      it "should return the nil when no matching UID instance exists" do
        value = '1.999.9999.1234.56789.999999'
        uid = LIBRARY.uid(value)
        uid.should be_nil
      end

      it "should return the matching UID instance" do
        value = '1.2.840.10008.1.1'
        uid = LIBRARY.uid(value)
        uid.should be_a UID
        uid.value.should eql value
        uid.name.should eql 'Verification SOP Class'
        uid.retired?.should be_false
      end

      it "should return the matching UID instance" do
        value = '1.2.840.10008.1.2.4.52' # Retired
        uid = LIBRARY.uid(value)
        uid.should be_a UID
        uid.value.should eql value
        uid.name.should eql 'JPEG Extended (Process 3 & 5) (Retired)'
        uid.retired?.should be_true
      end

      it "should return the matching (retired) UID instance" do
        value = '1.2.840.10008.15.1.1' # New uid in the 2011 edition
        uid = LIBRARY.uid(value)
        uid.should be_a UID
        uid.value.should eql value
        uid.name.should eql 'Universal Coordinated Time'
        uid.retired?.should be_false
      end

    end

  end
end