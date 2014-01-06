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
        expect(e.tag).to eql '0011,0011'
        expect(e.value).to eql 'Rex'
        expect(e.vr).to eql 'PN'
        expect(e.parent).to eql dcm
        expect(dcm.exists?('0011,0011')).to be_true
      end

      it "should add an Element (as specified) to the Item instance" do
        i = Item.new
        e = i.add_element('0011,0011', 'Rex', :name => 'Pet Name')
        expect(e.tag).to eql '0011,0011'
        expect(e.value).to eql 'Rex'
        expect(e.name).to eql 'Pet Name'
        expect(e.parent).to eql i
        expect(i.exists?('0011,0011')).to be_true
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
        expect(e.tag).to eql '0008,0082'
        expect(e.parent).to eql dcm
        expect(dcm.exists?('0008,0082')).to be_true
      end

      it "should add a Sequence (as specified) to the Item instance" do
        i = Item.new
        e = i.add_sequence('0011,0011', :name => 'Pet Sequence')
        expect(e.tag).to eql '0011,0011'
        expect(e.name).to eql 'Pet Sequence'
        expect(e.parent).to eql i
        expect(i.exists?('0011,0011')).to be_true
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
        expect(dcm.color?).to be_false
      end

      it "should return false when the DICOM object has greyscale pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        expect(dcm.color?).to be_false
      end

      it "should return true when the DICOM object has RGB pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
        expect(dcm.color?).to be_true
      end

      it "should return true when the DICOM object has palette color pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL)
        expect(dcm.color?).to be_true
      end

    end


    context "#compression?" do

      it "should return false when the DICOM object has no pixel data" do
        dcm = DObject.new
        expect(dcm.compression?).to be_false
      end

      it "should return false when the DICOM object has ordinary, uncompressed pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.compression?).to be_false
      end

      it "should return true when the DICOM object has JPG compressed pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
        expect(dcm.compression?).to be_true
      end

      it "should return true when the DICOM object has RLE compressed pixel data" do
        dcm = DObject.read(DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME)
        expect(dcm.compression?).to be_true
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
        expect(pixels.class).to eql Array
        expect(pixels.length).to eql 2
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
        expect(pixels.class).to eql String
        expect(pixels.length).to eql 2
      end

    end


    context "#pixels" do

      it "should return nil if no pixel data is present" do
        dcm = DObject.new
        expect(dcm.pixels).to be_nil
      end

      it "should return false if it is not able to decompress compressed pixel data" do
        dcm = DObject.new
        dcm.stubs(:exists?).returns(true)
        dcm.stubs(:compression?).returns(true)
        dcm.stubs(:decompress).returns(false)
        expect(dcm.pixels).to be_false
      end

      it "should return pixel data in an array" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels).to be_an(Array)
      end

      it "should return an array of length equal to the number of pixels in the pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels.length).to eql 65536 # 256*256 pixels
      end

      it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels.min).to eql 1024
      end

      it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels.max).to eql 1284
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '-72')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        expect(dcm.pixels(:remap => true).min).to eql 3000
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '148')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        expect(dcm.pixels(:remap => true).max).to eql 4000
      end

      it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels(:level => true).min).to eql 1053
      end

      it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels(:level => true).max).to eql 1137
      end

      it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels(:level => [1100, 100]).min).to eql 1050
      end

      it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels(:level => [1100, 100]).max).to eql 1150
      end

      it "should remap the pixel values using the requested window center & width values and give the expected minimum value, when using the NArray library" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels(:level => [1100, 100], :narray => true).min).to eql 1050
      end

      it "should remap the pixel values using the requested window center & width values and give the expected maximum value, when using the NArray library" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.pixels(:level => [1100, 100], :narray => true).max).to eql 1150
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
        expect(pixels.length).to eql 24
        expect(pixels).to eql Array.new(24) {|i| i}
      end

    end


    context "#narray" do

      it "should return nil if no pixel data is present" do
        dcm = DObject.new
        expect(dcm.narray).to be_nil
      end

      it "should return false if it is not able to decompress compressed pixel data" do
        dcm = DObject.new
        dcm.stubs(:exists?).returns(true)
        dcm.stubs(:compression?).returns(true)
        dcm.stubs(:decompress).returns(false)
        expect(dcm.narray).to be_false
      end

      it "should return pixel data in an NArray" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray).to be_an(NArray)
      end

      it "should return an NArray of length equal to the number of pixels in the pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray.length).to eql 65536 # 256*256 pixels
      end

      it "should return an NArray which is sized according to the dimensions of the 2D pixel image" do
        dcm = DObject.read(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON)
        narr = dcm.narray
        expect(narr.shape[0]).to eql 448 # nr of columns
        expect(narr.shape[1]).to eql 268 # nr of rows
        expect(narr.shape.length).to eql 2
      end

      it "should return a volumetric NArray when using the :volume option on a 2D pixel image" do
        dcm = DObject.read(DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON)
        narr = dcm.narray(:volume => true)
        expect(narr.shape[0]).to eql 1 # nr of frames
        expect(narr.shape[1]).to eql 448 # nr of columns
        expect(narr.shape[2]).to eql 268 # nr of rows
        expect(narr.shape.length).to eql 3
      end

      it "should properly decode the pixel data such that the minimum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray.min).to eql 1024
      end

      it "should properly decode the pixel data such that the maximum pixel value for this image is 1024" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray.max).to eql 1284
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected mininum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '-72')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        expect(dcm.narray(:remap => true).min).to eql 3000
      end

      it "should remap the pixel values according to the rescale slope and intercept values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.add(Element.new('0028,1052', '148')) # intercept
        dcm.add(Element.new('0028,1053', '3')) # slope
        expect(dcm.narray(:remap => true).max).to eql 4000
      end

      it "should remap the pixel values using the default window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray(:level => true).min).to eql 1053
      end

      it "should remap the pixel values using the default window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray(:level => true).max).to eql 1137
      end

      it "should remap the pixel values using the requested window center & width values and give the expected minimum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray(:level => [1100, 100]).min).to eql 1050
      end

      it "should remap the pixel values using the requested window center & width values and give the expected maximum value" do
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        expect(dcm.narray(:level => [1100, 100]).max).to eql 1150
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
          expect(@narr.shape[0]).to eql 2
        end

        it "should return a 3D NArray with the expected number of columns" do
          expect(@narr.shape[1]).to eql 3
        end

        it "should return a 3D NArray with the expected number of rows" do
          expect(@narr.shape[2]).to eql 4
        end

        it "should return an NArray with exactly 3 dimensions" do
          expect(@narr.shape.length).to eql 3
        end

        it "should return an NArray with the pixel values properly placed in the expected indices for each frame" do
          expect(@narr[0, true, true] == NArray.int(3, 4).indgen).to be_true
          expect(@narr[1, true, true] == NArray.int(3, 4).indgen + 12).to be_true
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
        expect(dcm['7FE0,0010'].bin).to eql file_string
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
        expect(dcm.num_frames).to eql 1
      end

      it "should return correct integer values for rows, columns and frames when all corresponding data elements are defined in the DICOM object" do
        dcm = DObject.new
        rows_used = 512
        columns_used = 256
        frames_used = 8
        dcm.add(Element.new('0028,0010', rows_used))
        dcm.add(Element.new('0028,0011', columns_used))
        dcm.add(Element.new('0028,0008', frames_used.to_s))
        expect(dcm.num_rows).to eql rows_used
        expect(dcm.num_cols).to eql columns_used
        expect(dcm.num_frames).to eql frames_used
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
        expect(f.read).to eql pixel_data
      end

      it "should write multiple files as expected, when a file extension is omitted" do
        dcm = DObject.read(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME) # 8 frames
        dcm.image_to_file(TMPDIR + 'data')
        expect(File.readable?(TMPDIR + 'data-0')).to be_true
        expect(File.readable?(TMPDIR + 'data-7')).to be_true
      end

      it "should write multiple files, using the expected file enumeration and image fragments, when the DICOM object has multi-fragment pixel data" do
        dcm = DObject.read(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME) # 8 frames
        dcm.image_to_file(TMPDIR + 'multi.dat')
        expect(File.readable?(TMPDIR + 'multi-0.dat')).to be_true
        expect(File.readable?(TMPDIR + 'multi-7.dat')).to be_true
        f0 = File.new(TMPDIR + 'multi-0.dat', 'rb')
        expect(f0.read).to eql dcm['7FE0,0010'][0][0].bin
        f7 = File.new(TMPDIR + 'multi-7.dat', 'rb')
        expect(f7.read).to eql dcm['7FE0,0010'][0][7].bin
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
        expect(dcm.children.length).to eql 2
        expect(dcm.exists?('0008,1140')).to be_false
        expect(dcm.exists?('0009,1140')).to be_false
        expect(dcm.exists?('0088,0200')).to be_false
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
        expect(i.children.length).to eql 2
        expect(i.exists?('0008,1140')).to be_false
        expect(i.exists?('0009,1140')).to be_false
        expect(i.exists?('0088,0200')).to be_false
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
        expect(dcm['7FE0,0010'].bin.length).to eql 4
        expect(dcm.decode_pixels(dcm['7FE0,0010'].bin)).to eql pixel_data
      end

      it "should encode the pixel array and update the DICOM object's pixel data element" do
        pixel_data = [0,42,0,42]
        dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
        dcm.pixels = pixel_data
        expect(dcm['7FE0,0010'].bin.length).to eql 8
        expect(dcm.decode_pixels(dcm['7FE0,0010'].bin)).to eql pixel_data
      end

      it "should encode the pixels of the NArray and write them to the DICOM object's pixel data element" do
        pixel_data = [0,42,0,42]
        dcm = DObject.new
        dcm.add(Element.new('0028,0100', 8)) # Bit depth
        dcm.add(Element.new('0028,0103', 0)) # Pixel Representation
        dcm.pixels = NArray.to_na(pixel_data)
        expect(dcm['7FE0,0010'].bin.length).to eql 4
        expect(dcm.decode_pixels(dcm['7FE0,0010'].bin)).to eql pixel_data
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
          expect(@dcm.pixels).to eql Array.new(24) {|i| i}
        end

        it "should encode the pixels of the (flat) Array such that the pixel values are properly placed in expected indices" do
          @dcm.pixels = Array.new(24) {|i| i}
          expect(@dcm.pixels).to eql Array.new(24) {|i| i}
        end

      end

    end


    # Note: Private method.
    context "#window_level_values" do

      it "should return the expected window level related values" do
        center = 300
        width = 600
        intercept = -1024
        slope = 1
        dcm = DObject.new
        dcm.add_element('0028,1050', center.to_s)
        dcm.add_element('0028,1051', width.to_s)
        dcm.add_element('0028,1052', intercept.to_s)
        dcm.add_element('0028,1053', slope.to_s)
        c, w, i, s = dcm.send(:window_level_values)
        expect(c).to eql center
        expect(w).to eql width
        expect(i).to eql intercept
        expect(s).to eql slope
      end

      it "should return the expected window level related values for this case of multiple center/width values" do
        center = 30
        width = 200
        intercept = -1000
        slope = 2
        dcm = DObject.new
        dcm.add_element('0028,1050', "#{center}\\500")
        dcm.add_element('0028,1051', "#{width}\\2000")
        dcm.add_element('0028,1052', intercept.to_s)
        dcm.add_element('0028,1053', slope.to_s)
        c, w, i, s = dcm.send(:window_level_values)
        expect(c).to eql center
        expect(w).to eql width
        expect(i).to eql intercept
        expect(s).to eql slope
      end

    end

  end

end