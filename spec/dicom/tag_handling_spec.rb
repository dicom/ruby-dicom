# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe "When handling Data Elements with tags as value (VR = 'AT')," do

    context DObject, "::read" do

      it "should be able to read a file containing a blank 'AT' tag, and set its value as nil" do
        dcm = DObject.read(DCM_AT_NO_VALUE)
        at_element = dcm["0028,0009"]
        expect(at_element.value).to be_nil
      end

      it "should be able to read a file containing an invalid 'AT' tag, handling the deviation by setting its value as nil" do
        dcm = DObject.read(DCM_AT_INVALID)
        at_element = dcm["0028,0009"]
        expect(at_element.value).to be_nil
      end

    end

    context DObject, "#value" do

      it "should return the proper tag string" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.value("0020,5000")).to eql "0010,0010"
      end

    end

    context DObject, "#value=()" do

      it "should encode the value as a proper binary tag, for a little endian DICOM object" do
        dcm = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        dcm["0020,5000"].value = "10B0,C0A0"
        expect(dcm["0020,5000"].bin).to eql "\260\020\240\300"
      end

    end

    context Element, "::new" do

      it "should properly encode its value as a binary tag in, using default (little endian) encoding" do
        element = Element.new("0020,5000", "10B0,C0A0")
        expect(element.bin).to eql "\260\020\240\300"
      end

      it "should accept the creation of an empty (nil-valued) AT element" do
        element = Element.new("0020,5000", nil)
        expect(element.bin).to eql ''
        expect(element.value).to be_nil
      end

      it "should accept the creation of an empty-stringed AT element" do
        element = Element.new("0020,5000", '')
        expect(element.bin).to eql ''
        expect(element.value).to eql ''
      end

    end

    context DObject, "#add" do

      it "should add the Data Element with its value properly encoded as a binary tag, for an empty (little endian) DICOM object" do
        dcm = DObject.new
        dcm.add(Element.new("0020,5000", "10B0,C0A0"))
        expect(dcm["0020,5000"].bin).to eql "\260\020\240\300"
      end

      it "should add the Data Element with its value properly encoded as a binary tag, for an empty (big endian) DICOM object" do
        dcm = DObject.new
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        dcm.add(Element.new("0020,5000", "10B0,C0A0"))
        expect(dcm["0020,5000"].bin).to eql "\020\260\300\240"
      end

    end

    context DObject, "#transfer_syntax=()" do

      it "should properly re-encode the Data Element value, when the endianness of the DICOM object is changed" do
        dcm = DObject.new
        dcm.add(Element.new("0020,5000", "10B0,C0A0"))
        dcm.transfer_syntax = EXPLICIT_BIG_ENDIAN
        expect(dcm["0020,5000"].bin).to eql "\020\260\300\240"
      end

    end

  end


  describe "When handling Data Element tags," do

    context DObject, "::read" do

      it "should have properly decoded this File Meta Header tag (from a DICOM file with big endian TS), using little endian byte order" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        expect(dcm.exists?("0002,0010")).to eql true
      end

      it "should have properly decoded the DICOM tag (from a DICOM file with big endian TS), using big endian byte order" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        expect(dcm.exists?("0008,0060")).to eql true
      end

    end

    context DObject, "#write" do

      before :each do
        @dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        @output = TMPDIR + File.basename(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
      end

      it "should properly encode File Meta Header tags (to a DICOM file with big endian TS), using little endian byte order" do
        @dcm.add(Element.new("0002,0100", "1.234.567"))
        @dcm.write(@output)
        dcm = DObject.read(@output)
        expect(dcm.exists?("0002,0100")).to eql true
      end

      it "should properly encode the DICOM tag (to a DICOM file with big endian TS), using big endian byte order" do
        @dcm.add(Element.new("0010,0021", "Man"))
        @dcm.write(@output)
        dcm = DObject.read(@output)
        expect(dcm.exists?("0010,0021")).to eql true
      end

      it "should properly re-encode the DICOM tag when switching from a big endian TS to a little endian TS" do
        @dcm.transfer_syntax = IMPLICIT_LITTLE_ENDIAN
        @dcm.write(@output)
        dcm = DObject.read(@output)
        expect(dcm.exists?("0008,0060")).to eql true
      end

      after :each do
        File.delete(@output)
      end

    end

  end


  describe "When specifying or querying data elements using tags" do

    context Element, "::new" do

      it "should always save tags using upper case letters (but accept tags specified with lower case letters)" do
        dcm = DObject.new
        dcm.add(e = Element.new("0020,000d", "1.234.567"))
        expect(e.tag).to eql "0020,000D"
        expect(dcm.exists?("0020,000D")).to eql true
      end

    end


    context Sequence, "::new" do

      it "should always save tags using upper case letters (but accept tags specified with lower case letters)" do
        dcm = DObject.new
        dcm.add(s = Sequence.new("300a,0040"))
        expect(s.tag).to eql "300A,0040"
        expect(dcm.exists?("300A,0040")).to eql true
      end

    end


    context Parent do

      context "#[]" do

        it "should accept upper cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("0020,000D", "1.234.567"))
          expect(dcm["0020,000D"]).to be_an Element
        end

        it "should accept lower cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("0020,000D", "1.234.567"))
          expect(dcm["0020,000d"]).to be_an Element
        end

      end

      context "#exists?" do

        it "should accept upper cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("0020,000D", "1.234.567"))
          expect(dcm.exists?("0020,000D")).to eql true
        end

        it "should accept lower cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("0020,000D", "1.234.567"))
          expect(dcm.exists?("0020,000d")).to eql true
        end

      end

      context "#group" do

        it "should accept upper cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          expect(dcm.group("300A").length).to eql 1
        end

        it "should accept lower cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          expect(dcm.group("300a").length).to eql 1
        end

      end

      context "#delete" do

        it "should accept upper cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          dcm.delete("300A,000A")
          expect(dcm.exists?("300A,000A")).to be_false
        end

        it "should accept lower cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          dcm.delete("300a,000a")
          expect(dcm.exists?("300A,000A")).to be_false
        end

      end

      context "#delete_group" do

        it "should accept upper cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          dcm.delete_group("300A")
          expect(dcm.exists?("300A,000A")).to be_false
        end

        it "should accept lower cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          dcm.delete_group("300a")
          expect(dcm.exists?("300A,000A")).to be_false
        end

      end

      context "#value" do

        it "should accept upper cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          expect(dcm.value("300A,000A")).to be_a String
        end

        it "should accept lower cased tag letters" do
          dcm = DObject.new
          dcm.add(Element.new("300A,000A", "Palliative"))
          expect(dcm.value("300a,000a")).to be_a String
        end

      end

    end

  end

end