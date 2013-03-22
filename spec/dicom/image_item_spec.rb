# encoding: UTF-8

require 'spec_helper'
require 'narray'


module DICOM

  describe ImageItem do

    before :all do
      DICOM.logger = Logger.new(STDOUT)
      DICOM.logger.level = Logger::FATAL
    end


    context "#add_element" do

      it "should add an Element (as specified) to a DObject instance" do
        dcm = DObject.new
        e = dcm.add_element('0011,0011', 'Rex', :vr => 'PN')
        e.tag.should eql '0011,0011'
        e.value.should eql 'Rex'
        e.vr.should eql 'PN'
        e.parent.should eql dcm
        dcm.exists?('0011,0011').should be_true
      end

      it "should add an Element (as specified) to the Item instance" do
        i = Item.new
        e = i.add_element('0011,0011', 'Rex', :name => 'Pet Name')
        e.tag.should eql '0011,0011'
        e.value.should eql 'Rex'
        e.name.should eql 'Pet Name'
        e.parent.should eql i
        i.exists?('0011,0011').should be_true
      end

      it "should give a NoMethodError if called on a Sequence" do
        s = Sequence.new('0008,0082')
        expect{s.add_element('0011,0011', 'Rex')}.to raise_error(NoMethodError)
      end

      it "should give a NoMethodError if called on an Element" do
        e = Element.new('0010,0010', 'John Doe')
        expect{e.add_element('0011,0011', 'Rex')}.to raise_error(NoMethodError)
      end

    end


    context "#add_sequence" do

      it "should add a Sequence (as specified) to a DObject instance" do
        dcm = DObject.new
        e = dcm.add_sequence('0008,0082')
        e.tag.should eql '0008,0082'
        e.parent.should eql dcm
        dcm.exists?('0008,0082').should be_true
      end

      it "should add a Sequence (as specified) to the Item instance" do
        i = Item.new
        e = i.add_sequence('0011,0011', :name => 'Pet Sequence')
        e.tag.should eql '0011,0011'
        e.name.should eql 'Pet Sequence'
        e.parent.should eql i
        i.exists?('0011,0011').should be_true
      end

      it "should give a NoMethodError if called on a Sequence" do
        s = Sequence.new('0008,0082')
        expect{s.add_sequence('0008,0082')}.to raise_error(NoMethodError)
      end

      it "should give a NoMethodError if called on an Element" do
        e = Element.new('0010,0010', 'John Doe')
        expect{e.add_sequence('0008,0082')}.to raise_error(NoMethodError)
      end

    end


    context "#color?" do

      it "should return false when the DICOM object has no pixel data" do
        dcm = DObject.new
        dcm.color?.should be_false
      end

      it "should return false when the DICOM object has greyscale pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        dcm.color?.should be_false
      end

      it "should return true when the DICOM object has RGB pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        dcm.color?.should be_true
      end

      it "should return true when the DICOM object has palette color pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL)
        dcm.color?.should be_true
      end

    end


    context "#compression?" do

      it "should return false when the DICOM object has no pixel data" do
        dcm = DObject.new
        dcm.compression?.should be_false
      end

      it "should return false when the DICOM object has ordinary, uncompressed pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.compression?.should be_false
      end

      it "should return true when the DICOM object has JPG compressed pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        dcm.compression?.should be_true
      end

      it "should return true when the DICOM object has RLE compressed pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME)
        dcm.compression?.should be_true
      end

    end


    context "#decode_pixels" do

      it "should raise an error when the DICOM object doesn't have any of the necessary data elements needed to decode pixel data" do
        dcm = DObject.new
        expect {dcm.decode_pixels('0000')}.to raise_error
      end

      it "should raise an error when the DICOM object is missing the 'Pixel Representation' element, needed to decode pixel data" do
        dcm = DObject.new
        dcm.add(Element.new('0028,0100', 16))
        expect {dcm.decode_pixels('0000')}.to raise_error
      end

      it "should raise an ArgumentError when a non-string is supplied" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect {dcm.decode_pixels(42)}.to raise_error(ArgumentError)
      end

      it "should return decoded pixel values in an array with a length determined by the input string length and the bit depth of the object's pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        pixels = dcm.decode_pixels('0000')
        pixels.class.should eql Array
        pixels.length.should eql 2
      end

    end


    context "#encode_pixels" do

      it "should raise an error when the DICOM object doesn't have the necessary data elements needed to encode the pixel data" do
        dcm = DObject.new
        expect {dcm.encode_pixels([42, 42])}.to raise_error
      end

      it "should raise an error when the DICOM object is missing the 'Pixel Representation' element, needed to encode the pixel data" do
        dcm = DObject.new
        dcm.add(Element.new('0028,0100', 16))
        expect {dcm.encode_pixels([42, 42])}.to raise_error
      end

      it "should raise an ArgumentError when a non-array is supplied" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect {dcm.encode_pixels('42')}.to raise_error(ArgumentError)
      end

      it "should return encoded pixel values in a string with a length determined by the input array length and the bit depth of the object's pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL)
        pixels = dcm.encode_pixels([42, 42])
        pixels.class.should eql String
        pixels.length.should eql 2
      end

    end


    context "#pixels" do

      it "should return nil if no pixel data is present" do
        dcm = DObject.new
        dcm.pixels.should be_nil
      end

      it "should return false if it is not able to decompress compressed pixel data" do
        dcm = DObject.new
        dcm.stubs(:exists?).returns(true)
        dcm.stubs(:compression?).returns(true)
        dcm.stubs(:decompress).returns(false)
        dcm.pixels.should be_false
      end

      it "should return pixel data in an array" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels.should be_an(Array)
      end

      it "should return an array of length equal to the number of pixels in the pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels.length.should eql 65536 # 256*256 pixels
      end

      it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels.min.should eql 1024
      end

      it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels.max.should eql 1284
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '-72')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        dcm.pixels(:remap => true).min.should eql 3000
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '148')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        dcm.pixels(:remap => true).max.should eql 4000
      end

      it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels(:level => true).min.should eql 1053
      end

      it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels(:level => true).max.should eql 1137
      end

      it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels(:level => [1100, 100]).min.should eql 1050
      end

      it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels(:level => [1100, 100]).max.should eql 1150
      end

      it "should remap the pixel values using the requested window center & width values and give the expected minimum value, when using the NArray library" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels(:level => [1100, 100], :narray => true).min.should eql 1050
      end

      it "should remap the pixel values using the requested window center & width values and give the expected maximum value, when using the NArray library" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels(:level => [1100, 100], :narray => true).max.should eql 1150
      end

      it "should use NArray to process the pixel values when the :narray option is used" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.expects(:process_presentation_values_narray).once
        dcm.pixels(:level => [1100, 100],:narray => true)
      end

      it "should return the pixel values properly placed in the expected indices on a 3D Pixel Data volume" do
        dcm = DObject.new
        Element.new('0002,0010', EXPLICIT_LITTLE_ENDIAN, :parent => dcm) # TS
        Element.new('0028,0008', '2', :parent => dcm) # Frames
        Element.new('0028,0010', 4, :parent => dcm) # Rows
        Element.new('0028,0011', 3, :parent => dcm) # Columns
        Element.new('0028,0100', 16, :parent => dcm) # Bit Depth
        Element.new('0028,0103', 0, :parent => dcm) # Pixel Rep.
        pixels = Array.new(24) {|i| i}
        dcm.pixels = pixels
        pixels = dcm.pixels
        pixels.length.should eql 24
        pixels.should eql Array.new(24) {|i| i}
      end

    end


    context "#narray" do

      it "should return nil if no pixel data is present" do
        dcm = DObject.new
        dcm.narray.should be_nil
      end

      it "should return false if it is not able to decompress compressed pixel data" do
        dcm = DObject.new
        dcm.stubs(:exists?).returns(true)
        dcm.stubs(:compression?).returns(true)
        dcm.stubs(:decompress).returns(false)
        dcm.narray.should be_false
      end

      it "should return pixel data in an NArray" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray.should be_an(NArray)
      end

      it "should return an NArray of length equal to the number of pixels in the pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray.length.should eql 65536 # 256*256 pixels
      end

      it "should return an NArray which is sized according to the dimensions of the 2D pixel image" do
        dcm = DObject.read(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON)
        narr = dcm.narray
        narr.shape[0].should eql 448 # nr of columns
        narr.shape[1].should eql 268 # nr of rows
        narr.shape.length.should eql 2
      end

      it "should return a volumetric NArray when using the :volume option on a 2D pixel image" do
        dcm = DObject.read(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON)
        narr = dcm.narray(:volume => true)
        narr.shape[0].should eql 1 # nr of frames
        narr.shape[1].should eql 448 # nr of columns
        narr.shape[2].should eql 268 # nr of rows
        narr.shape.length.should eql 3
      end

      it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray.min.should eql 1024
      end

      it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray.max.should eql 1284
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '-72')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        dcm.narray(:remap => true).min.should eql 3000
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '148')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        dcm.narray(:remap => true).max.should eql 4000
      end

      it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray(:level => true).min.should eql 1053
      end

      it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray(:level => true).max.should eql 1137
      end

      it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray(:level => [1100, 100]).min.should eql 1050
      end

      it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.narray(:level => [1100, 100]).max.should eql 1150
      end

      context "[on a 3D pixel volume]" do

        before :each do
          dcm = DObject.new
          Element.new('0002,0010', EXPLICIT_LITTLE_ENDIAN, :parent => dcm) # TS
          Element.new('0028,0008', '2', :parent => dcm) # Frames
          Element.new('0028,0010', 4, :parent => dcm) # Rows
          Element.new('0028,0011', 3, :parent => dcm) # Columns
          Element.new('0028,0100', 16, :parent => dcm) # Bit Depth
          Element.new('0028,0103', 0, :parent => dcm) # Pixel Rep.
          pixels = Array.new(24) {|i| i}
          dcm.pixels = pixels
          @narr = dcm.narray
        end

        it "should return a 3D NArray with the expected number of frames" do
          @narr.shape[0].should eql 2
        end

        it "should return a 3D NArray with the expected number of columns" do
          @narr.shape[1].should eql 3
        end

        it "should return a 3D NArray with the expected number of rows" do
          @narr.shape[2].should eql 4
        end

        it "should return an NArray with exactly 3 dimensions" do
          @narr.shape.length.should eql 3
        end

        it "should return an NArray with the pixel values properly placed in the expected indices for each frame" do
          (@narr[0, true, true] == NArray.int(3, 4).indgen).should be_true
          (@narr[1, true, true] == NArray.int(3, 4).indgen + 12).should be_true
        end

      end

    end


    context "#image_from_file" do

      it "should raise an ArgumentError when a non-string argument is passed" do
        dcm = DObject.new
        expect {dcm.image_from_file(42)}.to raise_error(ArgumentError)
      end

      it "should copy the content of the specified file to the DICOM object's pixel data element" do
        file_string = 'abcdefghijkl'
        File.open(TMPDIR + 'string.dat', 'wb') {|f| f.write(file_string) }
        dcm = DObject.new
        dcm.image_from_file(TMPDIR + 'string.dat')
        dcm['7FE0,0010'].bin.should eql file_string
      end

    end


    context "#image_properties" do

      it "should raise an error when the 'Columns' data element is missing from the DICOM object" do
        dcm = DObject.new
        dcm.add(Element.new('0028,0010', 512)) # Rows
        expect {dcm.image_properties}.to raise_error
      end

      it "should raise an error when the 'Rows' data element is missing from the DICOM object" do
        dcm = DObject.new
        dcm.add(Element.new('0028,0011', 512)) # Columns
        expect {dcm.image_properties}.to raise_error
      end

      it "should return frames (=1) when the 'Number of Frames' data element is missing from the DICOM object" do
        dcm = DObject.new
        dcm.num_frames.should eql 1
      end

      it "should return correct integer values for rows, columns and frames when all corresponding data elements are defined in the DICOM object" do
        dcm = DObject.new
        rows_used = 512
        columns_used = 256
        frames_used = 8
        dcm.add(Element.new('0028,0010', rows_used))
        dcm.add(Element.new('0028,0011', columns_used))
        dcm.add(Element.new('0028,0008', frames_used.to_s))
        dcm.num_rows.should eql rows_used
        dcm.num_cols.should eql columns_used
        dcm.num_frames.should eql frames_used
      end

    end


    context "#image_to_file" do

      it "should raise an ArgumentError when a non-string argument is passed" do
        dcm = DObject.new
        expect {dcm.image_to_file(42)}.to raise_error(ArgumentError)
      end

      it "should write the DICOM object's pixel data string to the specified file" do
        pixel_data = 'abcdefghijkl'
        dcm = DObject.new
        dcm.add(Element.new('7FE0,0010', pixel_data, :encoded => true))
        dcm.image_to_file(TMPDIR + 'string.dat')
        f = File.new(TMPDIR + 'string.dat', 'rb')
        f.read.should eql pixel_data
      end

      it "should write multiple files as expected, when a file extension is omitted" do
        dcm = DObject.read(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME) # 8 frames
        dcm.image_to_file(TMPDIR + 'data')
        File.readable?(TMPDIR + 'data-0').should be_true
        File.readable?(TMPDIR + 'data-7').should be_true
      end

      it "should write multiple files, using the expected file enumeration and image fragments, when the DICOM object has multi-fragment pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME) # 8 frames
        dcm.image_to_file(TMPDIR + 'multi.dat')
        File.readable?(TMPDIR + 'multi-0.dat').should be_true
        File.readable?(TMPDIR + 'multi-7.dat').should be_true
        f0 = File.new(TMPDIR + 'multi-0.dat', 'rb')
        f0.read.should eql dcm['7FE0,0010'][0][0].bin
        f7 = File.new(TMPDIR + 'multi-7.dat', 'rb')
        f7.read.should eql dcm['7FE0,0010'][0][7].bin
      end

    end


    context "#delete_sequences" do

      it "should delete all sequences from the DICOM object" do
        dcm = DObject.new
        dcm.add(Element.new('0010,0030', '20000101'))
        dcm.add(Sequence.new('0008,1140'))
        dcm.add(Sequence.new('0009,1140'))
        dcm.add(Sequence.new('0088,0200'))
        dcm['0008,1140'].add_item
        dcm.add(Element.new('0011,0030', '42'))
        dcm.delete_sequences
        dcm.children.length.should eql 2
        dcm.exists?('0008,1140').should be_false
        dcm.exists?('0009,1140').should be_false
        dcm.exists?('0088,0200').should be_false
      end

      it "should delete all sequences from the Item" do
        i = Item.new
        i.add(Element.new('0010,0030', '20000101'))
        i.add(Sequence.new('0008,1140'))
        i.add(Sequence.new('0009,1140'))
        i.add(Sequence.new('0088,0200'))
        i['0008,1140'].add_item
        i.add(Element.new('0011,0030', '42'))
        i.delete_sequences
        i.children.length.should eql 2
        i.exists?('0008,1140').should be_false
        i.exists?('0009,1140').should be_false
        i.exists?('0088,0200').should be_false
      end

    end


    context "#pixels=()" do

      it "should raise an ArgumentError when a non-array argument is passed" do
        dcm = DObject.new
        expect {dcm.pixels = 42}.to raise_error(ArgumentError)
      end

      it "should encode the pixel array and write it to the DICOM object's pixel data element" do
        pixel_data = [0,42,0,42]
        dcm = DObject.new
        dcm.add(Element.new('0028,0100', 8)) # Bit depth
        dcm.add(Element.new('0028,0103', 0)) # Pixel Representation
        dcm.pixels = pixel_data
        dcm['7FE0,0010'].bin.length.should eql 4
        dcm.decode_pixels(dcm['7FE0,0010'].bin).should eql pixel_data
      end

      it "should encode the pixel array and update the DICOM object's pixel data element" do
        pixel_data = [0,42,0,42]
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels = pixel_data
        dcm['7FE0,0010'].bin.length.should eql 8
        dcm.decode_pixels(dcm['7FE0,0010'].bin).should eql pixel_data
      end

      it "should encode the pixels of the NArray and write them to the DICOM object's pixel data element" do
        pixel_data = [0,42,0,42]
        dcm = DObject.new
        dcm.add(Element.new('0028,0100', 8)) # Bit depth
        dcm.add(Element.new('0028,0103', 0)) # Pixel Representation
        dcm.pixels = NArray.to_na(pixel_data)
        dcm['7FE0,0010'].bin.length.should eql 4
        dcm.decode_pixels(dcm['7FE0,0010'].bin).should eql pixel_data
      end

      context "[on a 3D pixel volume]" do

        before :each do
          @dcm = DObject.new
          Element.new('0002,0010', EXPLICIT_LITTLE_ENDIAN, :parent => @dcm) # TS
          Element.new('0028,0008', '2', :parent => @dcm) # Frames
          Element.new('0028,0010', 4, :parent => @dcm) # Rows
          Element.new('0028,0011', 3, :parent => @dcm) # Columns
          Element.new('0028,0100', 16, :parent => @dcm) # Bit Depth
          Element.new('0028,0103', 0, :parent => @dcm) # Pixel Rep.
        end

        it "should encode the pixels of the NArray such that the pixel values are properly placed in the expected indices for each frame" do
          narr = NArray.int(2, 3, 4)
          narr[0, true, true] = NArray.int(3, 4).indgen
          narr[1, true, true] = NArray.int(3, 4).indgen + 12
          @dcm.pixels = narr
          @dcm.pixels.should eql Array.new(24) {|i| i}
        end

        it "should encode the pixels of the (flat) Array such that the pixel values are properly placed in expected indices" do
          @dcm.pixels = Array.new(24) {|i| i}
          @dcm.pixels.should eql Array.new(24) {|i| i}
        end

      end

    end

  end

end