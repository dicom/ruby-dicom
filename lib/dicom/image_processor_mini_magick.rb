module DICOM
  module ImageProcessor

    # This module contains methods for interacting with pixel data using the mini_magick gem.
    #
    module DcmMiniMagick

      class << self

        # Creates image objects from an array of compressed, binary string blobs.
        #
        # @param [Array<String>] blobs an array of binary string blobs containing compressed pixel data
        # @return [Array<MiniMagick::Image>, FalseClass] - an array of images, or false (if decompression failed)
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
        # @note This feature is not available as of yet in the mini_magick image processor.
        #   If this feature is needed, please try another image processor (RMagick).
        #
        # @param [MiniMagick::Image] image a mini_magick image object
        # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
        # @return [Array<Integer>] an array of pixel values
        #
        def export_pixels(image, photometry)
          raise ArgumentError, "Expected MiniMagick::Image, got #{image.class}." unless image.is_a?(MiniMagick::Image)
          raise "Exporting pixels is not yet available with the mini_magick processor. Please try another image processor (RMagick)."
        end

        # Creates an image object from a binary string blob.
        #
        # @param [String] blob binary string blob containing pixel data
        # @param [Integer] columns the number of columns
        # @param [Integer] rows the number of rows
        # @param [Integer] depth the bit depth of the encoded pixel data
        # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
        # @param [String] format the image format to use
        # @return [Magick::Image] a mini_magick image object
        #
        def import_pixels(blob, columns, rows, depth, photometry, format='png')
          image = MiniMagick::Image.import_pixels(blob, columns, rows, depth, im_map(photometry), format)
        end

        # Converts a given DICOM photometry string to a mini_magick pixel map string.
        #
        # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
        # @return [String] a mini_magick pixel map string
        #
        def im_map(photometry)
          raise ArgumentError, "Expected String, got #{photometry.class}." unless photometry.is_a?(String)
          if photometry.include?('COLOR') or photometry.include?('RGB')
            return 'rgb'
          elsif photometry.include?('YBR')
            return 'ybr'
          else
            return 'gray' # (Assuming monochromeX - greyscale)
          end
        end

      end

    end
  end
end