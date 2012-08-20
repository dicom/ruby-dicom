# encoding: ASCII-8BIT

require 'spec_helper'

module DICOM

  describe DLibrary do

    context "#element" do

      it "should return the matching DictionaryElement" do
        tag = '0010,0010'
        element = LIBRARY.element(tag)
        element.should be_a DictionaryElement
        element.tag.should eql tag
      end

      it "should return nil when no match is made" do
        LIBRARY.element('FFFF,ABCD').should be_nil
      end

    end


    context "#get_syntax_description" do

      it "should return the expected Name corresponding to this UID" do
        name = LIBRARY.get_syntax_description('1.2.840.10008.1.1')
        name.should eql 'Verification SOP Class'
      end

      it "should return the expected Name corresponding to this UID" do
        name = LIBRARY.get_syntax_description('1.2.840.10008.1.2.4.52') # Retired
        name.should eql 'JPEG Extended (Process 3 & 5) (Retired)'
      end

      it "should return the expected Name corresponding to this UID" do
        name = LIBRARY.get_syntax_description('1.2.840.10008.1.2.6.2')
        name.should eql 'XML Encoding'
      end

      it "should return the expected Name corresponding to this UID" do
        name = LIBRARY.get_syntax_description('1.2.840.10008.5.1.1.4.2') # Retired
        name.should eql 'Referenced Image Box SOP Class (Retired)'
      end

      it "should return the expected Name corresponding to this UID" do
        name = LIBRARY.get_syntax_description('1.2.840.10008.5.1.4.1.1.481.8')
        name.should eql 'RT Ion Plan Storage'
      end

      it "should return the expected Name corresponding to this UID" do
        name = LIBRARY.get_syntax_description('1.2.840.10008.15.0.4.8')
        name.should eql 'dicomTransferCapability'
      end

      it "should return the expected Name corresponding to this UID" do
        name = LIBRARY.get_syntax_description('1.2.840.10008.15.1.1') # New UID in the 2011 edition
        name.should eql 'Universal Coordinated Time'
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

  end
end