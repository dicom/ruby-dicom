# encoding: ASCII-8BIT

# Specification for the image methods using the RMagick interface as the image processor.

require 'spec_helper'
require 'RMagick'


module DICOM

  describe ImageItem, "#get_image_magick [using :rmagick]" do

    before :each do
      DICOM.image_processor = :rmagick
    end

    it "should return nil if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      obj.get_image_magick.should be_nil
    end

    it "should return false if it is not able to decompress compressed pixel data" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj["0002,0010"].value = rand(10**10).to_s
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      obj.get_image_magick.should be_false
    end

    it "should raise an ArgumentError when an unsupported bit depth is used" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj["0028,0100"].value = 42
      expect {obj.get_image_magick}.to raise_error(ArgumentError)
    end

    it "should raise an error when an invalid Pixel Representation is set" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      obj["0028,0103"].value = 42
      expect {obj.get_image_magick}.to raise_error
    end

    it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
    end

    it "should decompress the RLE encoded pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_EXPLICIT_MR_RLE_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
    end

    it "should return false when not suceeding in decompressing the pixel data of this DICOM file" do
      obj = DObject.new(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should eql false
    end

    it "should read the pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
    end

    it "should process the pixel data according to the :level parameter and return an image object" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      image = obj.get_image_magick(:level => true)
      image.should be_a(Magick::Image)
    end

    it "should read the RGP colored pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
      # Visual test:
      image.normalize.write(TMPDIR + "visual_test_rgb_color.png")
    end

    it "should read the palette colored pixel data of this DICOM file and return an image object" do
      obj = DObject.new(DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL, :verbose => false)
      image = obj.get_image_magick
      image.should be_a(Magick::Image)
      # Visual test:
      image.normalize.write(TMPDIR + "visual_test_palette_color.png")
    end

  end


  describe ImageItem, "#get_images_magick [using :rmagick]" do

    before :each do
      DICOM.image_processor = :rmagick
    end

    it "should return an emtpy array if no pixel data is present" do
      obj = DObject.new(nil, :verbose => false)
      images = obj.get_images_magick
      images.should be_an(Array)
      images.length.should eql 0
    end

    it "should return an empty array if it is not able to decompress compressed pixel data" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      obj["0002,0010"].value = rand(10**10).to_s
      obj.stubs(:compression?).returns(true)
      obj.stubs(:decompress).returns(false)
      images = obj.get_images_magick
      images.should be_an(Array)
      images.length.should eql 0
    end

    it "should return an empty array when not suceeding in decompressing the pixel data of this DICOM file" do
      obj = DObject.new(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_an(Array)
      images.length.should eql 0
    end

    it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return the image object in an array" do
      obj = DObject.new(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 1
      images.first.should be_a(Magick::Image)
    end

    it "should decompress the RLE encoded pixel data of this DICOM file and return the image object in an array" do
      obj = DObject.new(DCM_EXPLICIT_MR_RLE_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 1
      images.first.should be_a(Magick::Image)
    end

    it "should decompress the JPEG2K encoded multiframe pixel data of this DICOM file and return the image objects in an array" do
      obj = DObject.new(DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 8
      images.first.should be_a(Magick::Image)
      images.last.should be_a(Magick::Image)
    end

    it "should read the pixel data of this DICOM file and return the image object in an array" do
      obj = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      images = obj.get_images_magick
      images.should be_a(Array)
      images.length.should eql 1
      images.first.should be_a(Magick::Image)
    end

  end


  describe ImageItem, "#set_image_magick [using :rmagick]" do

    it "should raise an ArgumentError when a non-image argument is passed" do
      obj = DObject.new(nil, :verbose => false)
      expect {obj.set_image_magick(42)}.to raise_error(ArgumentError)
    end

    it "should export the pixels of an image object and write them to the DICOM object's pixel data element" do
      obj1 = DObject.new(DCM_IMPLICIT_MR_16BIT_MONO2, :verbose => false)
      image = obj1.get_image_magick(:level => true)
      obj2 = DObject.new(nil, :verbose => false)
      obj2.add(Element.new("0028,0004", "MONOCHROME2")) # Photometric Interpretation
      obj2.add(Element.new("0028,0010", 256)) # Rows
      obj2.add(Element.new("0028,0011", 256)) # Columns
      obj2.add(Element.new("0028,0100", 16)) # Bit depth
      obj2.add(Element.new("0028,0103", 1)) # Pixel Representation
      obj2.set_image_magick(image)
      obj2["7FE0,0010"].bin.length.should eql obj1["7FE0,0010"].bin.length
      # Save a set of images to disk for visual comparison:
      image_full = obj1.get_image_magick
      image_full.normalize.write(TMPDIR + "visual_test1_" + "full_range.png")
      image.normalize.write(TMPDIR + "visual_test1_" + "default_range.png")
      obj2.get_image_magick.normalize.write(TMPDIR + "visual_test1_" + "default_range_extracted_written_extracted.png")
      obj1.get_image_magick(:remap => true).normalize.write(TMPDIR + "visual_test1_" + "full_range_remapped.png")
      obj1.get_image_magick(:level => [1095, 84]).normalize.write(TMPDIR + "visual_test1_" + "custom_range_equal_to_default.png")
      obj1.get_image_magick(:level => [1000, 100]).normalize.write(TMPDIR + "visual_test1_" + "custom_range.png")
    end

  end

end