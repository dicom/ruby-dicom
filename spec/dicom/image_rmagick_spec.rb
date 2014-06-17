# encoding: UTF-8

# Specification for the image methods using the RMagick interface as the image processor.

require 'spec_helper'


module DICOM

  context "With :rmagick as image processor" do

    describe ImageItem do

      describe "#image" do

        before :example do
          DICOM.image_processor = :rmagick
        end

        it "should return nil if no pixel data is present" do
          dcm = DObject.new
          expect(dcm.image).to be_nil
        end

        it "should log a warning when it fails to decompress compressed pixel data" do
          dcm = DObject.read(DCM_INVALID_COMPRESSION)
          DICOM.logger.expects(:warn)
          dcm.image
        end

        it "should return false when it fails to decompress compressed pixel data" do
          dcm = DObject.read(DCM_INVALID_COMPRESSION)
          expect(dcm.image).to be_falsey
        end

        it "should raise an ArgumentError when an unsupported bit depth is used" do
          dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
          dcm["0028,0100"].value = 42
          expect {dcm.image}.to raise_error(ArgumentError)
        end

        it "should raise an error when an invalid Pixel Representation is set" do
          dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
          dcm["0028,0103"].value = 42
          expect {dcm.image}.to raise_error
        end

        it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
          image = dcm.image
          expect(image).to be_a(Magick::Image)
        end

        it "should decompress the RLE encoded pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_EXPLICIT_MR_RLE_MONO2)
          image = dcm.image
          expect(image).to be_a(Magick::Image)
        end

        it "should return false when not suceeding in decompressing the pixel data of this DICOM file" do
          dcm = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
          image = dcm.image
          expect(image).to eql false
        end

        it "should read the pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
          image = dcm.image
          expect(image).to be_a(Magick::Image)
        end

        it "should process the pixel data according to the :level parameter and return an image object" do
          dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
          image = dcm.image(:level => true)
          expect(image).to be_a(Magick::Image)
        end

        it "should read the RGP colored pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG)
          image = dcm.image
          expect(image).to be_a(Magick::Image)
          # Visual test:
          image.normalize.write(TMPDIR + "visual_test_rgb_color.png")
        end

        it "should read the palette colored pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL)
          image = dcm.image
          expect(image).to be_a(Magick::Image)
          # Visual test:
          image.normalize.write(TMPDIR + "visual_test_palette_color.png")
        end

      end


      describe "#images" do

        before :example do
          DICOM.image_processor = :rmagick
        end

        it "should return an emtpy array if no pixel data is present" do
          dcm = DObject.new
          images = dcm.images
          expect(images).to be_an(Array)
          expect(images.length).to eql 0
        end

        it "should return an empty array if it is not able to decompress compressed pixel data" do
          dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
          dcm["0002,0010"].value = rand(10**10).to_s
          dcm.stubs(:compression?).returns(true)
          dcm.stubs(:decompress).returns(false)
          images = dcm.images
          expect(images).to be_an(Array)
          expect(images.length).to eql 0
        end

        it "should return an empty array when not suceeding in decompressing the pixel data of this DICOM file" do
          dcm = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
          images = dcm.images
          expect(images).to be_an(Array)
          expect(images.length).to eql 0
        end

        it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return the image object in an array" do
          dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
          images = dcm.images
          expect(images).to be_a(Array)
          expect(images.length).to eql 1
          expect(images.first).to be_a(Magick::Image)
        end

        it "should decompress the RLE encoded pixel data of this DICOM file and return the image object in an array" do
          dcm = DObject.read(DCM_EXPLICIT_MR_RLE_MONO2)
          images = dcm.images
          expect(images).to be_a(Array)
          expect(images.length).to eql 1
          expect(images.first).to be_a(Magick::Image)
        end

        it "should decompress the JPEG2K encoded multiframe pixel data of this DICOM file and return the image objects in an array" do
          dcm = DObject.read(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME)
          images = dcm.images
          expect(images).to be_a(Array)
          expect(images.length).to eql 8
          expect(images.first).to be_a(Magick::Image)
          expect(images.last).to be_a(Magick::Image)
        end

        it "should read the pixel data of this DICOM file and return the image object in an array" do
          dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
          images = dcm.images
          expect(images).to be_a(Array)
          expect(images.length).to eql 1
          expect(images.first).to be_a(Magick::Image)
        end

      end


      describe "#image=" do

        it "should raise an ArgumentError when a non-image argument is passed" do
          dcm = DObject.new
          expect {dcm.image = 42}.to raise_error(ArgumentError)
        end

        it "should export the pixels of an image object and write them to the DICOM object's pixel data element" do
          dcm1 = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
          image = dcm1.image(:level => true)
          dcm2 = DObject.new
          dcm2.add(Element.new("0028,0004", "MONOCHROME2")) # Photometric Interpretation
          dcm2.add(Element.new("0028,0010", 256)) # Rows
          dcm2.add(Element.new("0028,0011", 256)) # Columns
          dcm2.add(Element.new("0028,0100", 16)) # Bit depth
          dcm2.add(Element.new("0028,0103", 1)) # Pixel Representation
          dcm2.image = image
          expect(dcm2["7FE0,0010"].bin.length).to eql dcm1["7FE0,0010"].bin.length
          # Save a set of images to disk for visual comparison:
          image_full = dcm1.image
          image_full.normalize.write(TMPDIR + "visual_test1_" + "full_range.png")
          image.normalize.write(TMPDIR + "visual_test1_" + "default_range.png")
          dcm2.image.normalize.write(TMPDIR + "visual_test1_" + "default_range_extracted_written_extracted.png")
          dcm1.image(:remap => true).normalize.write(TMPDIR + "visual_test1_" + "full_range_remapped.png")
          dcm1.image(:level => [1095, 84]).normalize.write(TMPDIR + "visual_test1_" + "custom_range_equal_to_default.png")
          dcm1.image(:level => [1000, 100]).normalize.write(TMPDIR + "visual_test1_" + "custom_range.png")
        end

      end

    end

  end

end