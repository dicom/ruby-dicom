# encoding: ASCII-8BIT

require 'spec_helper'
require 'narray'


module DICOM

  describe ImageItem, "#color?" do

    it "should return false when the DICOM object has no pixel data" do
      obj = DObject.new(nil, :verbose => false)
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


  describe ImageItem, "#compression?" do

    it "should return false when the DICOM object has no pixel data" do
      obj = DObject.new(nil, :verbose => false)
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


  describe ImageItem, "#decode_pixels" do

    it "should raise an error when the DICOM object doesn't have any of the necessary data elements needed to decode pixel data" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.decode_pixels("0000")}.to raise_error
    end

    it "should raise an error when the DICOM object is missing the 'Pixel Representation' element, needed to decode pixel data" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0028,0100", 16))
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


  describe ImageItem, "#encode_pixels" do

    it "should raise an error when the DICOM object doesn't have the necessary data elements needed to encode the pixel data" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.encode_pixels([42, 42])}.to raise_error
    end

    it "should raise an error when the DICOM object is missing the 'Pixel Representation' element, needed to encode the pixel data" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0028,0100", 16))
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


  describe ImageItem, "#pixels" do

    it "should return nil if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      obj.pixels.should be_nil
    end

    it "should return false if it is not able to decompress compressed pixel data" do
      obj = DObject.new(nil, :verbose => false)
      obj.stubs(:exists?).returns(true)
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      obj.pixels.should be_false
    end

    it "should return pixel data in an array" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels.should be_an(Array)
    end

    it "should return an array of length equal to the number of pixels in the pixel data" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels.length.should eql 65536 # 256*256 pixels
    end

    it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels.min.should eql 1024
    end

    it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels.max.should eql 1284
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(Element.new("0028,1052", "-72")) # intercept
      obj.add(Element.new("0028,1053", "3")) # slope
      obj.pixels(:remap => true).min.should eql 3000
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(Element.new("0028,1052", "148")) # intercept
      obj.add(Element.new("0028,1053", "3")) # slope
      obj.pixels(:remap => true).max.should eql 4000
    end

    it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels(:level => true).min.should eql 1053
    end

    it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels(:level => true).max.should eql 1137
    end

    it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels(:level => [1100, 100]).min.should eql 1050
    end

    it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels(:level => [1100, 100]).max.should eql 1150
    end

    it "should remap the pixel values using the requested window center & width values and give the expected minimum value, when using the NArray library" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels(:level => [1100, 100], :narray => true).min.should eql 1050
    end

    it "should remap the pixel values using the requested window center & width values and give the expected maximum value, when using the NArray library" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels(:level => [1100, 100], :narray => true).max.should eql 1150
    end

    it "should use NArray to process the pixel values when the :narray option is used" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.expects(:process_presentation_values_narray).once
      obj.pixels(:level => [1100, 100],:narray => true)
    end

  end


  describe ImageItem, "#narray" do

    it "should return nil if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      obj.narray.should be_nil
    end

    it "should return false if it is not able to decompress compressed pixel data" do
      obj = DObject.new(nil, :verbose => false)
      obj.stubs(:exists?).returns(true)
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      obj.narray.should be_false
    end

    it "should return pixel data in an NArray" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray.should be_an(NArray)
    end

    it "should return an NArray of length equal to the number of pixels in the pixel data" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray.length.should eql 65536 # 256*256 pixels
    end

    it "should return an NArray which is sized according to the dimensions of the 2D pixel image" do
      obj = DObject.new(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON, :verbose => false)
      narr = obj.narray
      narr.shape[0].should eql 448 # nr of columns
      narr.shape[1].should eql 268 # nr of rows
      narr.shape.length.should eql 2
    end

    it "should return a volumetric NArray when using the :volume option on a 2D pixel image" do
      obj = DObject.new(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON, :verbose => false)
      narr = obj.narray(:volume => true)
      narr.shape[0].should eql 1 # nr of frames
      narr.shape[1].should eql 448 # nr of columns
      narr.shape[2].should eql 268 # nr of rows
      narr.shape.length.should eql 3
    end

    it "should return an NArray which is sized according to the dimensions of the 3D pixel volume" do
      obj = DObject.new(DCM_EXPLICIT_RTDOSE_16BIT_MONO2_3D_VOLUME, :verbose => false)
      narr = obj.narray
      narr.shape[0].should eql 126 # nr of frames
      narr.shape[1].should eql 82 # nr of columns
      narr.shape[2].should eql 6 # nr of rows
      narr.shape.length.should eql 3
    end

    it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray.min.should eql 1024
    end

    it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray.max.should eql 1284
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(Element.new("0028,1052", "-72")) # intercept
      obj.add(Element.new("0028,1053", "3")) # slope
      obj.narray(:remap => true).min.should eql 3000
    end

    it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.add(Element.new("0028,1052", "148")) # intercept
      obj.add(Element.new("0028,1053", "3")) # slope
      obj.narray(:remap => true).max.should eql 4000
    end

    it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray(:level => true).min.should eql 1053
    end

    it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray(:level => true).max.should eql 1137
    end

    it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray(:level => [1100, 100]).min.should eql 1050
    end

    it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.narray(:level => [1100, 100]).max.should eql 1150
    end

  end


  describe ImageItem, "#image_from_file" do

    it "should raise an ArgumentError when a non-string argument is passed" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.image_from_file(42)}.to raise_error(ArgumentError)
    end

    it "should copy the content of the specified file to the DICOM object's pixel data element" do
      file_string = "abcdefghijkl"
      File.open(TMPDIR + "string.dat", 'wb') {|f| f.write(file_string) }
      obj = DObject.new(nil, :verbose => false)
      obj.image_from_file(TMPDIR + "string.dat")
      obj["7FE0,0010"].bin.should eql file_string
    end

  end

  describe ImageItem, "#image_properties" do

    it "should raise an error when the 'Columns' data element is missing from the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0028,0010", 512)) # Rows
      expect {obj.image_properties}.to raise_error
    end

    it "should raise an error when the 'Rows' data element is missing from the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0028,0011", 512)) # Columns
      expect {obj.image_properties}.to raise_error
    end

    it "should return frames (=1) when the 'Number of Frames' data element is missing from the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.num_frames.should eql 1
    end

    it "should return correct integer values for rows, columns and frames when all corresponding data elements are defined in the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      rows_used = 512
      columns_used = 256
      frames_used = 8
      obj.add(Element.new("0028,0010", rows_used))
      obj.add(Element.new("0028,0011", columns_used))
      obj.add(Element.new("0028,0008", frames_used.to_s))
      obj.num_rows.should eql rows_used
      obj.num_cols.should eql columns_used
      obj.num_frames.should eql frames_used
    end

  end


  describe ImageItem, "#image_to_file" do

    it "should raise an ArgumentError when a non-string argument is passed" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.image_to_file(42)}.to raise_error(ArgumentError)
    end

    it "should write the DICOM object's pixel data string to the specified file" do
      pixel_data = "abcdefghijkl"
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("7FE0,0010", pixel_data, :encoded => true))
      obj.image_to_file(TMPDIR + "string.dat")
      f = File.new(TMPDIR + "string.dat", "rb")
      f.read.should eql pixel_data
    end

    it "should write multiple files as expected, when a file extension is omitted" do
      obj = DObject.new(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME, :verbose => false) # 8 frames
      obj.image_to_file(TMPDIR + "data")
      File.readable?(TMPDIR + "data-0").should be_true
      File.readable?(TMPDIR + "data-7").should be_true
    end

    it "should write multiple files, using the expected file enumeration and image fragments, when the DICOM object has multi-fragment pixel data" do
      obj = DObject.new(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME, :verbose => false) # 8 frames
      obj.image_to_file(TMPDIR + "multi.dat")
      File.readable?(TMPDIR + "multi-0.dat").should be_true
      File.readable?(TMPDIR + "multi-7.dat").should be_true
      f0 = File.new(TMPDIR + "multi-0.dat", "rb")
      f0.read.should eql obj["7FE0,0010"][0][0].bin
      f7 = File.new(TMPDIR + "multi-7.dat", "rb")
      f7.read.should eql obj["7FE0,0010"][0][7].bin
    end

  end


  describe ImageItem, "#remove_sequences" do

    it "should remove all sequences from the DICOM object" do
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0010,0030", "20000101"))
      obj.add(Sequence.new("0008,1140"))
      obj.add(Sequence.new("0009,1140"))
      obj.add(Sequence.new("0088,0200"))
      obj["0008,1140"].add_item
      obj.add(Element.new("0011,0030", "42"))
      obj.remove_sequences
      obj.children.length.should eql 2
      obj.exists?("0008,1140").should be_false
      obj.exists?("0009,1140").should be_false
      obj.exists?("0088,0200").should be_false
    end

    it "should remove all sequences from the Item" do
      i = Item.new
      i.add(Element.new("0010,0030", "20000101"))
      i.add(Sequence.new("0008,1140"))
      i.add(Sequence.new("0009,1140"))
      i.add(Sequence.new("0088,0200"))
      i["0008,1140"].add_item
      i.add(Element.new("0011,0030", "42"))
      i.remove_sequences
      i.children.length.should eql 2
      i.exists?("0008,1140").should be_false
      i.exists?("0009,1140").should be_false
      i.exists?("0088,0200").should be_false
    end

  end


  describe ImageItem, "#pixels=()" do

    it "should raise an ArgumentError when a non-array argument is passed" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.pixels = 42}.to raise_error(ArgumentError)
    end

    it "should encode the pixel array and write it to the DICOM object's pixel data element" do
      pixel_data = [0,42,0,42]
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0028,0100", 8)) # Bit depth
      obj.add(Element.new("0028,0103", 0)) # Pixel Representation
      obj.pixels = pixel_data
      obj["7FE0,0010"].bin.length.should eql 4
      obj.decode_pixels(obj["7FE0,0010"].bin).should eql pixel_data
    end

    it "should encode the pixel array and update the DICOM object's pixel data element" do
      pixel_data = [0,42,0,42]
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj.pixels = pixel_data
      obj["7FE0,0010"].bin.length.should eql 8
      obj.decode_pixels(obj["7FE0,0010"].bin).should eql pixel_data
    end

    it "should encode the pixels of the NArray and write them to the DICOM object's pixel data element" do
      pixel_data = [0,42,0,42]
      obj = DObject.new(nil, :verbose => false)
      obj.add(Element.new("0028,0100", 8)) # Bit depth
      obj.add(Element.new("0028,0103", 0)) # Pixel Representation
      obj.pixels = NArray.to_na(pixel_data)
      obj["7FE0,0010"].bin.length.should eql 4
      obj.decode_pixels(obj["7FE0,0010"].bin).should eql pixel_data
    end

  end

end