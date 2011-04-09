module DICOM
  module ImageProcessor
    module DcmMiniMagick

      class << self

        # Creates image objects from an array of compressed, binary string blobs.
        # Returns an array of images. If decompression fails, returns false.
        #
        # === Parameters
        #
        # * <tt>blobs</tt> -- An array of binary string blobs containing compressed pixel data.
        #
        #--
        # FIXME: Work in progress
        def decompress(blobs)
          pixels = Array.new
          # We attempt to decompress the pixels with ImageMagick:
          begin
            strings.each do |string|
              image = MiniMagick::Image.read(string)
              if color?
                image = image.first if image.kind_of?(Array)
                pixel_frame = image.export_pixels(0, 0, image.columns, image.rows, "RGB")
              else
                pixel_frame = image.export_pixels(0, 0, image.columns, image.rows, "I")
              end
              pixels << pixel_frame
            end
          rescue
            add_msg("Warning: Decoding the compressed image data from this DICOM object was NOT successful!\n" + $!.to_s)
            pixels = false
          end
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
          image = MiniMagick::Image.import_pixels(blob, columns, rows, depth, im_map(photometry), "png")
        end

        # Returns an ImageMagick pixel map string based on the input DICOM photometry string.
        #
        # === Parameters
        #
        # * <tt>photometry</tt> -- String describing the photometry of the pixel data. Example: 'MONOCHROME1' or 'COLOR'.
        #
        def im_map(photometry)
          raise ArgumentError, "Expected String, got #{photometry.class}." unless photometry.is_a?(String)
          if photometry.include?("COLOR") or photometry.include?("RGB")
            return "rgb"
          elsif photometry.include?("YBR")
            return "ybr"
          else
            return "gray" # (Assuming monochromeX - greyscale)
          end
        end

      end

    end
  end
end