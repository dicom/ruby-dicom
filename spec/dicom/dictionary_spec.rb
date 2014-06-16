# encoding: UTF-8

require 'spec_helper'

module DICOM

  describe DLibrary do

    context "#add_element" do

      it "should raise an ArgumentError when a non-DictionaryElement is passed as an argument" do
        expect {LIBRARY.add_element('0011,0013')}.to raise_error(ArgumentError)
      end

      it "should add this dictionary element to ruby-dicom's element dictionary" do
        tag = '5005,7007'
        name = 'My custom tag'
        vrs = ['LO']
        vm = '2'
        retired = 'R'
        de = DictionaryElement.new(tag, name, vrs, vm, retired)
        LIBRARY.add_element(de)
        e = LIBRARY.element(tag)
        expect(e.tag).to eql tag
        expect(e.name).to eql name
        expect(e.vrs).to eql vrs
        expect(e.vm).to eql vm
        expect(e.retired).to eql retired
        expect(e.retired?).to be_truthy
      end

    end

    context "#add_element_dictionary" do

      it "should add this dictionary to ruby-dicom's element dictionary" do
        LIBRARY.add_element_dictionary(DICT_ELEMENTS)
        e1 = LIBRARY.element('0009,010C')
        expect(e1.name).to eql 'World Domination Scheme UID'
        expect(e1.vr).to eql 'UI'
        expect(e1.vm).to eql '1'
        expect(e1.retired?).to be_falsey
        e2 = LIBRARY.element('2027,010F')
        expect(e2.name).to eql 'Code Smell Context Identifier'
        expect(e2.vr).to eql 'CS'
        expect(e2.vm).to eql '1'
        expect(e2.retired?).to be_truthy
        e3 = LIBRARY.element('AAAB,0110')
        expect(e3.name).to eql 'Github Commit Sequence'
        expect(e3.vr).to eql 'SQ'
        expect(e3.vm).to eql '1'
        expect(e3.retired?).to be_falsey
        e4 = LIBRARY.element('FFFF,0112')
        expect(e4.name).to eql 'Bug Registry'
        expect(e4.vr).to eql 'UL'
        expect(e4.vm).to eql '1-n'
        expect(e4.retired?).to be_falsey
      end

    end


    context "#add_uid" do

      it "should raise an ArgumentError when a non-DictionaryElement is passed as an argument" do
        expect {LIBRARY.add_uid('1.2.840.10008.1.1.333')}.to raise_error(ArgumentError)
      end

      it "should add this dictionary element to ruby-dicom's uid dictionary" do
        value = '1.2.840.10008.1.1.77'
        name = 'Some Transfer Syntax'
        type = 'Transfer Syntax'
        retired = 'R'
        uid = UID.new(value, name, type, retired)
        LIBRARY.add_uid(uid)
        u = LIBRARY.uid(value)
        expect(u.value).to eql value
        expect(u.name).to eql name
        expect(u.type).to eql type
        expect(u.retired).to eql retired
        expect(u.retired?).to be_truthy
      end

    end

    context "#add_uid_dictionary" do

      it "should add this dictionary to ruby-dicom's uid dictionary" do
        LIBRARY.add_uid_dictionary(DICT_UIDS)
        u1 = LIBRARY.uid('1.2.840.10008.1.1.333')
        expect(u1.value).to eql '1.2.840.10008.1.1.333'
        expect(u1.name).to eql 'Custom SOP Class'
        expect(u1.type).to eql 'SOP Class'
        expect(u1.retired?).to be_falsey
        u2 = LIBRARY.uid('1.2.840.10008.1.1.555')
        expect(u2.value).to eql '1.2.840.10008.1.1.555'
        expect(u2.name).to eql 'Custom TS Syntax'
        expect(u2.type).to eql 'Transfer Syntax'
        expect(u2.retired?).to be_truthy
      end

    end


    context "#element" do

      it "should return the matching DictionaryElement" do
        tag = '0010,0010'
        element = LIBRARY.element(tag)
        expect(element).to be_a DictionaryElement
        expect(element.tag).to eql tag
        expect(element.retired?).to be_falsey
      end

      it "should return the matching (retired) DictionaryElement" do
        tag = '0000,51B0' # Retired
        element = LIBRARY.element(tag)
        expect(element).to be_a DictionaryElement
        expect(element.tag).to eql tag
        expect(element.retired?).to be_truthy
      end

      it "should create a 'group length element' when given a group length type tag" do
        element = LIBRARY.element('0010,0000')
        expect(element.name).to eql 'Group Length'
        expect(element.vr).to eql 'UL'
        expect(element.retired?).to be_falsey
      end

      it "should create a 'group length element' when given a private group length type tag" do
        element = LIBRARY.element('0011,0000')
        expect(element.name).to eql 'Group Length'
        expect(element.vr).to eql 'UL'
        expect(element.retired?).to be_falsey
      end

      it "should create a 'private element' when given a private type tag" do
        element = LIBRARY.element('0011,ABCD')
        expect(element.name).to eql 'Private'
        expect(element.vr).to eql 'UN'
        expect(element.retired?).to be_falsey
      end

      it "should create an 'unknown element' when no match is made" do
        element = LIBRARY.element('EEEE,ABCD')
        expect(element.name).to eql 'Unknown'
        expect(element.vr).to eql 'UN'
        expect(element.retired?).to be_falsey
      end

      it "should give the expected name when it contains an apostrophe" do
        tag = '0010,0010'
        element = LIBRARY.element(tag)
        expect(element.name).to eql "Patient's Name"
      end

      it "should give the name of this tag encoded as UTF-8" do
        tag = '0018,1153'
        element = LIBRARY.element(tag)
        expect(element.name.encoding).to eql Encoding::UTF_8
      end

      it "should give the proper UTF-8 name string of this tag" do
        tag = '0018,1153'
        element = LIBRARY.element(tag)
        expect(element.name).to eql 'Exposure in µAs'
      end

    end


    context "#name_and_vr [Command Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0000,0000')
        expect(name).to eql 'Command Group Length'
        expect(vr).to eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0000,1005')
        expect(name).to eql 'Attribute Identifier List'
        expect(vr).to eql 'AT'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0000,51B0') # Retired command element
        expect(name).to eql 'Overlays'
        expect(vr).to eql 'US'
      end

    end


    context "#name_and_vr [File Meta Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0002,0000')
        expect(name).to eql 'File Meta Information Group Length'
        expect(vr).to eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0002,0010')
        expect(name).to eql 'Transfer Syntax UID'
        expect(vr).to eql 'UI'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0002,0102')
        expect(name).to eql 'Private Information'
        expect(vr).to eql 'OB'
      end

    end


    context "#name_and_vr [Directory Structuring Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0004,1130')
        expect(name).to eql 'File-set ID'
        expect(vr).to eql 'CS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0004,1220')
        expect(name).to eql 'Directory Record Sequence'
        expect(vr).to eql 'SQ'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0004,1600')
        expect(name).to eql 'Number of References'
        expect(vr).to eql 'UL'
      end

    end


    context "#name_and_vr [Data Elements]" do

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0001')
        expect(name).to eql 'Length to End'
        expect(vr).to eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0018')
        expect(name).to eql 'SOP Instance UID'
        expect(vr).to eql 'UI'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0034')
        expect(name).to eql 'Overlay Time'
        expect(vr).to eql 'TM'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0018,9511')
        expect(name).to eql 'Secondary Positioner Scan Start Angle'
        expect(vr).to eql 'FL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0054,0039')
        expect(name).to eql 'Phase Description'
        expect(vr).to eql 'CS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('3002,0022')
        expect(name).to eql 'Radiation Machine SAD'
        expect(vr).to eql 'DS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0014,4056') # New tag in the 2011 edition
        expect(name).to eql 'Coupling Medium'
        expect(vr).to eql 'ST'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0028,0453') # (0028,04x3)
        expect(name).to eql 'Coefficient Coding Pointers'
        expect(vr).to eql 'AT'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0028,08A8') # (0028,08x8)
        expect(name).to eql 'Image Data Location'
        expect(vr).to eql 'AT'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1000,ABC0') # (1000,xxx0)
        expect(name).to eql 'Escape Triplet'
        expect(vr).to eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1000,DEF5') # (1000,xxx5)
        expect(name).to eql 'Shift Table Triplet'
        expect(vr).to eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1010,1234') # (1010,xxxx)
        expect(name).to eql 'Zonal Map'
        expect(vr).to eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('5012,2600') # (50xx,2600)
        expect(name).to eql 'Curve Referenced Overlay Sequence'
        expect(vr).to eql 'SQ'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('60CC,0011') # (60xx,0011)
        expect(name).to eql 'Overlay Columns'
        expect(vr).to eql 'US'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('60EE,0110') # (60xx,0110)
        expect(name).to eql 'Overlay Format'
        expect(vr).to eql 'CS'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('7FAA,0020') # (7Fxx,0020)
        expect(name).to eql 'Variable Coefficients SDVN'
        expect(vr).to eql 'OW'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('7FE0,0010')
        expect(name).to eql 'Pixel Data'
        expect(vr).to eql 'OW' # (OW or OB)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('FFFE,E000')
        expect(name).to eql 'Item'
        expect(vr).to eql '  ' # (not defined)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('FFFE,E00D')
        expect(name).to eql 'Item Delimitation Item'
        expect(vr).to eql '  ' # (not defined)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('FFFE,E0DD')
        expect(name).to eql 'Sequence Delimitation Item'
        expect(vr).to eql '  ' # (not defined)
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('0008,0000') # (Group Length)
        expect(name).to eql 'Group Length'
        expect(vr).to eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('7FE0,0000') # (Group Length)
        expect(name).to eql 'Group Length'
        expect(vr).to eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1111,0000') # (Private Group Length)
        expect(name).to eql 'Group Length'
        expect(vr).to eql 'UL'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('AAAA,FFFF') # (An undefined, but not private tag)
        expect(name).to eql 'Unknown'
        expect(vr).to eql 'UN'
      end

      it "should return the expected Name and VR for this tag" do
        name, vr = LIBRARY.name_and_vr('1111,2222') # (A private tag)
        expect(name).to eql 'Private'
        expect(vr).to eql 'UN'
      end

    end


    context "#uid" do

      it "should return the nil when no matching UID instance exists" do
        value = '1.999.9999.1234.56789.999999'
        uid = LIBRARY.uid(value)
        expect(uid).to be_nil
      end

      it "should return the matching UID instance" do
        value = '1.2.840.10008.1.1'
        uid = LIBRARY.uid(value)
        expect(uid).to be_a UID
        expect(uid.value).to eql value
        expect(uid.name).to eql 'Verification SOP Class'
        expect(uid.retired?).to be_falsey
      end

      it "should return the matching UID instance" do
        value = '1.2.840.10008.1.2.4.52' # Retired
        uid = LIBRARY.uid(value)
        expect(uid).to be_a UID
        expect(uid.value).to eql value
        expect(uid.name).to eql 'JPEG Extended (Process 3 & 5) (Retired)'
        expect(uid.retired?).to be_truthy
      end

      it "should return the matching (retired) UID instance" do
        value = '1.2.840.10008.15.1.1' # New uid in the 2011 edition
        uid = LIBRARY.uid(value)
        expect(uid).to be_a UID
        expect(uid.value).to eql value
        expect(uid.name).to eql 'Universal Coordinated Time'
        expect(uid.retired?).to be_falsey
      end

      it "should return the name of the UID encoded as UTF-8" do
        value = '1.2.840.10008.1.2.4.100'
        uid = LIBRARY.uid(value)
        expect(uid.name.encoding).to eql Encoding::UTF_8
      end

    end

  end
end