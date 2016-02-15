# encoding: UTF-8

# Specification for the image methods using the MiniMagick wrapper as the image processor.

require 'spec_helper'


module DICOM

  context "With :mini_magick as image processor" do

    describe ImageItem do

      describe "#image" do

        before :example do
          DICOM.image_processor = :mini_magick
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

        it "should read the pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_IMPLICIT_MR_16BIT_MONO2)
          image = dcm.image
          expect(image).to be_a(MiniMagick::Image)
        end

        it "should decompress the JPEG Baseline encoded pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
          image = dcm.image
          expect(image).to be_a(MiniMagick::Image)
        end

        it "should decompress the RLE encoded pixel data of this DICOM file and return an image object" do
          dcm = DObject.read(DCM_EXPLICIT_MR_RLE_MONO2)
          image = dcm.image
          expect(image).to be_a(MiniMagick::Image)
        end

        it "should return false when not suceeding in decompressing the pixel data of this DICOM file" do
          dcm = DObject.read(DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2)
          image = dcm.image
          expect(image).to eql false
        end

      end

    end

  end

end