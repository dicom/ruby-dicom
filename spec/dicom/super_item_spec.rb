# coding: UTF-8

require 'spec_helper'


module DICOM

  describe SuperItem, "#color?" do
    
    it "should return false when the DICOM object has no pixel data" do
      obj = DObject.new(nil)
      obj.color?.should be_false
    end
    
    it "should return false when the DICOM object has greyscale pixel data" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj.color?.should be_false
    end
    
    it "should return true when the DICOM object has RGB pixel data" do
      obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG, :verbose => false)
      obj.color?.should be_true
    end
    
    it "should return true when the DICOM object has palette color pixel data" do
      obj = DObject.new(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL, :verbose => false)
      obj.color?.should be_true
    end
    
  end
  
  
  describe SuperItem, "#compression?" do
    
    it "should return false when the DICOM object has no pixel data" do
      obj = DObject.new(nil)
      obj.compression?.should be_false
    end
    
    it "should return false when the DICOM object has ordinary, uncompressed pixel data" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.compression?.should be_false
    end
    
    it "should return true when the DICOM object has JPG compressed pixel data" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj.compression?.should be_true
    end
    
    it "should return true when the DICOM object has RLE compressed pixel data" do
      obj = DObject.new(DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME, :verbose => false)
      obj.compression?.should be_true
    end
    
  end
  
  
  describe SuperItem, "#decode_pixels" do
    
    it "should raise an error when the DICOM object doesn't have the necessary data elements needed to decode the pixel data" do
      obj = DObject.new(nil)
      expect {obj.decode_pixels("0000")}.to raise_error
    end
    
    it "should raise an ArgumentError when a non-string is supplied" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      expect {obj.decode_pixels(42)}.to raise_error(ArgumentError)
    end
    
    it "should return decoded pixel values in an array with a length determined by the input string length and the bit depth of the object's pixel data" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      pixels = obj.decode_pixels("0000")
      pixels.class.should eql Array
      pixels.length.should eql 2
    end
    
  end
  
  
  describe SuperItem, "#encode_pixels" do
    
    it "should raise an error when the DICOM object doesn't have the necessary data elements needed to decode the pixel data" do
      obj = DObject.new(nil)
      expect {obj.encode_pixels([42, 42])}.to raise_error
    end
    
    it "should raise an ArgumentError when a non-array is supplied" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      expect {obj.encode_pixels("42")}.to raise_error(ArgumentError)
    end
    
    it "should return encoded pixel values in a string with a length determined by the input array length and the bit depth of the object's pixel data" do
      obj = DObject.new(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL, :verbose => false)
      pixels = obj.encode_pixels([42, 42])
      pixels.class.should eql String
      pixels.length.should eql 2
    end
    
  end

end