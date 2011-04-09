# encoding: ASCII-8BIT

require 'spec_helper'
require 'narray'


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


  describe SuperItem, "#get_image" do

    it "should return nil if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      obj.get_image.should be_nil
    end

    it "should return false if it is not able to decompress compressed pixel data" do
      obj = DObject.new(nil, :verbose => false)
      obj.stubs(:exists?).returns(true)
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      obj.get_image.should be_false
    end

    it "should return pixel data in an array" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image.should be_an(Array)
    end

    it "should return an array of length equal to the number of pixels in the pixel data" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image.length.should eql 65536 # 256*256 pixels
    end

    it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image.min.should eql 1024
    end

    it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image.max.should eql 1284
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(DataElement.new("0028,1052", "-72")) # intercept
      obj.add(DataElement.new("0028,1053", "3")) # slope
      obj.get_image(:remap => true).min.should eql 3000
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(DataElement.new("0028,1052", "148")) # intercept
      obj.add(DataElement.new("0028,1053", "3")) # slope
      obj.get_image(:remap => true).max.should eql 4000
    end

    it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image(:level => true).min.should eql 1053
    end

    it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image(:level => true).max.should eql 1137
    end

    it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image(:level => [1100, 100]).min.should eql 1050
    end

    it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image(:level => [1100, 100]).max.should eql 1150
    end

    it "should remap the pixel values using the requested window center & width values and give the expected minimum value, when using the NArray library" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image(:level => [1100, 100], :narray => true).min.should eql 1050
    end

    it "should remap the pixel values using the requested window center & width values and give the expected maximum value, when using the NArray library" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image(:level => [1100, 100], :narray => true).max.should eql 1150
    end

    it "should use NArray to process the pixel values when the :narray option is used" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.expects(:process_presentation_values_narray).once
      obj.get_image(:level => [1100, 100],:narray => true)
    end

  end


  describe SuperItem, "#get_image_narray" do

    it "should return nil if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      obj.get_image_narray.should be_nil
    end

    it "should return false if it is not able to decompress compressed pixel data" do
      obj = DObject.new(nil, :verbose => false)
      obj.stubs(:exists?).returns(true)
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      obj.get_image_narray.should be_false
    end

    it "should return pixel data in an NArray" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray.should be_an(NArray)
    end

    it "should return an NArray of length equal to the number of pixels in the pixel data" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray.length.should eql 65536 # 256*256 pixels
    end

    # FIXME: Replace this dicom file with one that has pixel data where rows != columns.
    # Add another example with a dicom file which has 3d volume pixel data.
    it "should return an NArray which is sized according to the number of rows and columns in the pixel data" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      narr = obj.get_image_narray
      narr.shape[0].should eql 1 # nr of frames
      narr.shape[1].should eql 256
      narr.shape[2].should eql 256
      narr.shape.length.should eql 3
    end

    it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray.min.should eql 1024
    end

    it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray.max.should eql 1284
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(DataElement.new("0028,1052", "-72")) # intercept
      obj.add(DataElement.new("0028,1053", "3")) # slope
      obj.get_image_narray(:remap => true).min.should eql 3000
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(DataElement.new("0028,1052", "148")) # intercept
      obj.add(DataElement.new("0028,1053", "3")) # slope
      obj.get_image_narray(:remap => true).max.should eql 4000
    end

    it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray(:level => true).min.should eql 1053
    end

    it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray(:level => true).max.should eql 1137
    end

    it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray(:level => [1100, 100]).min.should eql 1050
    end

    it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.get_image_narray(:level => [1100, 100]).max.should eql 1150
    end

  end

end