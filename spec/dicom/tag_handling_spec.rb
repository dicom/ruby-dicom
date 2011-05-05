# encoding: ASCII-8BIT

require 'spec_helper'


module DICOM

  describe "When handling Data Elements with tags as value (VR = 'AT')," do

    context DObject, "#value" do

      it "should return the proper tag string" do
        obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
        obj.value("0020,5000").should eql "0010,0010"
      end

    end

    context DObject, "#value=()" do

      it "should encode the value as a proper binary tag, for a little endian DICOM object" do
        obj = DObject.new(DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
        obj["0020,5000"].value = "10B0,C0A0"
        obj["0020,5000"].bin.should eql "\260\020\240\300"
      end

    end

    context Element, "#new" do

      it "should properly encode its value as a binary tag in, using default (little endian) encoding" do
        element = Element.new("0020,5000", "10B0,C0A0")
        element.bin.should eql "\260\020\240\300"
      end

    end

    context DObject, "#add" do

      it "should add the Data Element with its value properly encoded as a binary tag, for an empty (little endian) DICOM object" do
        obj = DObject.new(nil, :verbose => false)
        obj.add(Element.new("0020,5000", "10B0,C0A0"))
        obj["0020,5000"].bin.should eql "\260\020\240\300"
      end

      it "should add the Data Element with its value properly encoded as a binary tag, for an empty (big endian) DICOM object" do
        obj = DObject.new(nil, :verbose => false)
        obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
        obj.add(Element.new("0020,5000", "10B0,C0A0"))
        obj["0020,5000"].bin.should eql "\020\260\300\240"
      end

    end

    context DObject, "#transfer_syntax=()" do

      it "should properly re-encode the Data Element value, when the endianness of the DICOM object is changed" do
        obj = DObject.new(nil, :verbose => false)
        obj.add(Element.new("0020,5000", "10B0,C0A0"))
        obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
        obj["0020,5000"].bin.should eql "\020\260\300\240"
      end

    end

  end


  describe "When handling Data Element tags," do

    context DObject, "#read" do

      it "should have properly decoded this File Meta Header tag (from a DICOM file with big endian TS), using little endian byte order" do
        obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG, :verbose => false)
        obj.exists?("0002,0010").should eql true
      end

      it "should have properly decoded the DICOM tag (from a DICOM file with big endian TS), using big endian byte order" do
        obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG, :verbose => false)
        obj.exists?("0008,0060").should eql true
      end

    end

    context DObject, "#write" do

      before :each do
        @obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG, :verbose => false)
        @output = TMPDIR + File.basename(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
      end

      it "should properly encode File Meta Header tags (to a DICOM file with big endian TS), using little endian byte order" do
        @obj.add(Element.new("0002,0100", "1.234.567"))
        @obj.write(@output)
        obj = DObject.new(@output, :verbose => false)
        obj.exists?("0002,0100").should eql true
      end

      it "should properly encode the DICOM tag (to a DICOM file with big endian TS), using big endian byte order" do
        @obj.add(Element.new("0010,0021", "Man"))
        @obj.write(@output)
        obj = DObject.new(@output, :verbose => false)
        obj.exists?("0010,0021").should eql true
      end

      it "should properly re-encode the DICOM tag when switching from a big endian TS to a little endian TS" do
        @obj.transfer_syntax = IMPLICIT_LITTLE_ENDIAN
        @obj.write(@output)
        obj = DObject.new(@output, :verbose => false)
        obj.exists?("0008,0060").should eql true
      end

      after :each do
        File.delete(@output)
      end

    end

  end

end