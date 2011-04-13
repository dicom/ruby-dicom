module DICOM
  module ImageProcessor
    module DcmRMagick

      class << self

        # Creates image objects from an array of compressed, binary string blobs.
        # Returns an array of images. If decompression fails, returns false.
        #
        # === Notes
        #
        # The method tries to use RMagick of unpacking, but it seems that ImageMagick is not able to handle most of the
        # compressed image variants used in the DICOM standard. To get a more robust implementation which is able to handle
        # most types of compressed DICOM files, something else is needed.
        #
        # Probably a good candidate to use is the PVRG-JPEG library, which seems to be able to handle everything that is jpeg.
        # It exists in the Ubuntu repositories, where it can be installed and run through terminal. For source code, and some
        # additional information, check this link:  http://www.panix.com/~eli/jpeg/
        #
        # Another idea would be to study how other open source libraries, like GDCM handle these files.
        #
        # === Parameters
        #
        # * <tt>blobs</tt> -- An array of binary string blobs containing compressed pixel data.
        #
        #--
        # The following transfer syntaxes have been verified as failing with ImageMagick:
        # TXS_JPEG_LOSSLESS_NH is not supported by (my) ImageMagick version: "Unsupported JPEG process: SOF type 0xc3"
        # TXS_JPEG_LOSSLESS_NH_FOP is not supported by (my) ImageMagick version: "Unsupported JPEG process: SOF type 0xc3"
        # TXS_JPEG_2000_PART1_LOSSLESS is not supported by (my) ImageMagick version: "jpc_dec_decodepkts failed"
        #
        def decompress(blobs)
          images = Array.new
          # We attempt to decompress the pixels using ImageMagick:
            blobs.each do |string|
              images << Magick::Image.from_blob(string).first
            end
          return images
        end

        # Extracts an array of pixels (integers) from an image object.
        #
        # === Parameters
        #
        # * <tt>image</tt> -- An Rmagick image object.
        #
        def export_pixels(image, photometry)
          raise ArgumentError, "Expected Magick::Image, got #{image.class}." unless image.is_a?(Magick::Image)
          pixels = image.export_pixels(0, 0, image.columns, image.rows, rm_map(photometry))
          return pixels
        end

        # Creates an image object from a binary string blob which contains raw pixel data.
        #
        # === Parameters
        #
        # * <tt>blob</tt> -- Binary string blob containing raw pixel data.
        # * <tt>columns</tt> -- Number of columns.
        # * <tt>rows</tt> -- Number of rows.
        # * <tt>depth</tt> -- Bit depth of the encoded pixel data.
        # * <tt>photometry</tt> -- String describing the DICOM photometry of the pixel data.
        # * <tt>format</tt> -- String describing the image format to be used when creating the image object. Defaults to 'png'.
        #
        def import_pixels(blob, columns, rows, depth, photometry, format="png")
          image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, rm_map(photometry), blob, rm_data_type(depth))
        end

        # Returns the RMagick StorageType pixel value corresponding to the given bit length.
        #
        def rm_data_type(bit_depth)
          return case bit_depth
          when 8
            Magick::CharPixel
          when 16
            Magick::ShortPixel
          else
            raise ArgumentError, "Unsupported bit depth #{bit_depth}."
          end
        end

        # Returns an RMagick pixel map string based on the input DICOM photometry string.
        #
        # === Parameters
        #
        # * <tt>photometry</tt> -- String describing the photometry of the pixel data. Example: 'MONOCHROME1' or 'COLOR'.
        #
        def rm_map(photometry)
          raise ArgumentError, "Expected String, got #{photometry.class}." unless photometry.is_a?(String)
          if photometry.include?("COLOR") or photometry.include?("RGB")
            return "RGB"
          elsif photometry.include?("YBR")
            return "YBR"
          else
            return "I" # (Assuming monochromeX - greyscale)
          end
        end

      end

    end
  end
end