# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe "When handling Data Elements with tags as value (VR = 'AT')," do

    context DObject, "#value" do

      it "should return the proper tag string" do
        obj = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        obj.value("0020,5000").should be nil
      end

    end

    context DObject, "#value=()" do

      it "should encode the value as a proper binary tag, for a little endian DICOM object" do
        obj = DObject.read(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2)
        obj["0020,5000"].value = "10B0,C0A0"
        obj["0020,5000"].bin.should eql "\260\020\240\300"
      end

    end

    context Element, "::new" do

      it "should properly encode its value as a binary tag in, using default (little endian) encoding" do
        element = Element.new("0020,5000", "10B0,C0A0")
        element.bin.should eql "\260\020\240\300"
      end

    end

    context DObject, "#add" do

      it "should add the Data Element with its value properly encoded as a binary tag, for an empty (little endian) DICOM object" do
        obj = DObject.new
        obj.add(Element.new("0020,5000", "10B0,C0A0"))
        obj["0020,5000"].bin.should eql "\260\020\240\300"
      end

      it "should add the Data Element with its value properly encoded as a binary tag, for an empty (big endian) DICOM object" do
        obj = DObject.new
        obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
        obj.add(Element.new("0020,5000", "10B0,C0A0"))
        obj["0020,5000"].bin.should eql "\020\260\300\240"
      end

    end

    context DObject, "#transfer_syntax=()" do

      it "should properly re-encode the Data Element value, when the endianness of the DICOM object is changed" do
        obj = DObject.new
        obj.add(Element.new("0020,5000", "10B0,C0A0"))
        obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
        obj["0020,5000"].bin.should eql "\020\260\300\240"
      end

    end

  end


  describe "When handling Data Element tags," do

    context DObject, "::read" do

      it "should have properly decoded this File Meta Header tag (from a DICOM file with big endian TS), using little endian byte order" do
        obj = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        obj.exists?("0002,0010").should eql true
      end

      it "should have properly decoded the DICOM tag (from a DICOM file with big endian TS), using big endian byte order" do
        obj = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        obj.exists?("0008,0060").should eql true
      end

    end

    context DObject, "#write" do

      before :each do
        @obj = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        @output = TMPDIR + File.basename(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
      end

      it "should properly encode File Meta Header tags (to a DICOM file with big endian TS), using little endian byte order" do
        @obj.add(Element.new("0002,0100", "1.234.567"))
        @obj.write(@output)
        obj = DObject.read(@output)
        obj.exists?("0002,0100").should eql true
      end

      it "should properly encode the DICOM tag (to a DICOM file with big endian TS), using big endian byte order" do
        @obj.add(Element.new("0010,0021", "Man"))
        @obj.write(@output)
        obj = DObject.read(@output)
        obj.exists?("0010,0021").should eql true
      end

      it "should properly re-encode the DICOM tag when switching from a big endian TS to a little endian TS" do
        @obj.transfer_syntax = IMPLICIT_LITTLE_ENDIAN
        @obj.write(@output)
        obj = DObject.read(@output)
        obj.exists?("0008,0060").should eql true
      end

      after :each do
        File.delete(@output)
      end

    end

  end


  describe "When specifying or querying data elements using tags" do

    context Element, "::new" do

      it "should always save tags using upper case letters (but accept tags specified with lower case letters)" do
        obj = DObject.new
        obj.add(e = Element.new("0020,000d", "1.234.567"))
        e.tag.should eql "0020,000D"
        obj.exists?("0020,000D").should eql true
      end

    end


    context Sequence, "::new" do

      it "should always save tags using upper case letters (but accept tags specified with lower case letters)" do
        obj = DObject.new
        obj.add(s = Sequence.new("300a,0040"))
        s.tag.should eql "300A,0040"
        obj.exists?("300A,0040").should eql true
      end

    end


    context Parent do

      context "#[]" do

        it "should accept upper cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("0020,000D", "1.234.567"))
          obj["0020,000D"].should be_an Element
        end

        it "should accept lower cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("0020,000D", "1.234.567"))
          obj["0020,000d"].should be_an Element
        end

      end

      context "#exists?" do

        it "should accept upper cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("0020,000D", "1.234.567"))
          obj.exists?("0020,000D").should eql true
        end

        it "should accept lower cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("0020,000D", "1.234.567"))
          obj.exists?("0020,000d").should eql true
        end

      end

      context "#group" do

        it "should accept upper cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.group("300A").length.should eql 1
        end

        it "should accept lower cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.group("300a").length.should eql 1
        end

      end

      context "#remove" do

        it "should accept upper cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.remove("300A,000A")
          obj.exists?("300A,000A").should be_false
        end

        it "should accept lower cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.remove("300a,000a")
          obj.exists?("300A,000A").should be_false
        end

      end

      context "#remove_group" do

        it "should accept upper cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.remove_group("300A")
          obj.exists?("300A,000A").should be_false
        end

        it "should accept lower cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.remove_group("300a")
          obj.exists?("300A,000A").should be_false
        end

      end

      context "#value" do

        it "should accept upper cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.value("300A,000A").should be_a String
        end

        it "should accept lower cased tag letters" do
          obj = DObject.new
          obj.add(Element.new("300A,000A", "Palliative"))
          obj.value("300a,000a").should be_a String
        end

      end

    end

  end

end