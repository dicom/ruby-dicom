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
        def decompress(blobs)
          images = Array.new
          # We attempt to decompress the pixels using ImageMagick:
          blobs.each do |string|
            images << MiniMagick::Image.read(string)
          end
          return images
        end

        # Extracts an array of pixels (integers) from an image object.
        #
        # === Notes
        #
        # * This feature is not available as of yet in the mini_magick image processor. If this feature is needed, please try another image processor (RMagick).
        #
        # === Parameters
        #
        # * <tt>image</tt> -- An MiniMagick image object.
        #
        def export_pixels(image, photometry)
          raise ArgumentError, "Expected MiniMagick::Image, got #{image.class}." unless image.is_a?(MiniMagick::Image)
          raise "Exporting pixels is not yet available with the mini_magick processor. Please try another image processor (RMagick)."
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
          image = MiniMagick::Image.import_pixels(blob, columns, rows, depth, im_map(photometry), format)
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