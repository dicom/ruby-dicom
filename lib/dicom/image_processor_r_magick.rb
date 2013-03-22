module DICOM
  module ImageProcessor

    # This module contains methods for interacting with pixel data using the RMagick gem.
    #
    module DcmRMagick

      class << self

        # Creates image objects from an array of compressed, binary string blobs.
        #
        # === Note
        #
        # The method tries to use RMagick for unpacking, but unortunately, it seems that
        # ImageMagick is not able to handle most of the compressed image variants used in the DICOM
        # standard. To get a more robust implementation which is able to handle most types of
        # compressed DICOM files, something else is needed.
        #
        # Probably a good candidate to use is the PVRG-JPEG library, which seems to be able to handle
        # everything that is jpeg. It exists in the Ubuntu repositories, where it can be installed and
        # run through terminal. For source code, and some additional information, check out this link:
        # http://www.panix.com/~eli/jpeg/
        #
        # Another idea would be to study how other open source libraries, like GDCM handle these files.
        #
        # @param [Array<String>] blobs an array of binary string blobs containing compressed pixel data
        # @return [Array<Magick::Image>, FalseClass] - an array of images, or false (if decompression failed)
        #
        def decompress(blobs)
          # FIXME:
          # The following transfer syntaxes have been verified as failing with ImageMagick:
          # TXS_JPEG_LOSSLESS_NH is not supported by (my) ImageMagick version: "Unsupported JPEG process: SOF type 0xc3"
          # TXS_JPEG_LOSSLESS_NH_FOP is not supported by (my) ImageMagick version: "Unsupported JPEG process: SOF type 0xc3"
          # TXS_JPEG_2000_PART1_LOSSLESS is not supported by (my) ImageMagick version: "jpc_dec_decodepkts failed"
          #
          images = Array.new
          # We attempt to decompress the pixels using ImageMagick:
            blobs.each do |string|
              images << Magick::Image.from_blob(string).first
            end
          return images
        end

        # Extracts an array of pixels (integers) from an image object.
        #
        # @param [Magick::Image] image an RMagick image object
        # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
        # @return [Array<Integer>] an array of pixel values
        #
        def export_pixels(image, photometry)
          raise ArgumentError, "Expected Magick::Image, got #{image.class}." unless image.is_a?(Magick::Image)
          pixels = image.export_pixels(0, 0, image.columns, image.rows, rm_map(photometry))
          return pixels
        end

        # Creates an image object from a binary string blob.
        #
        # @param [String] blob binary string blob containing pixel data
        # @param [Integer] columns the number of columns
        # @param [Integer] rows the number of rows
        # @param [Integer] depth the bit depth of the encoded pixel data
        # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
        # @param [String] format the image format to use
        # @return [Magick::Image] an RMagick image object
        #
        def import_pixels(blob, columns, rows, depth, photometry, format='png')
          image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, rm_map(photometry), blob, rm_data_type(depth))
        end

        # Converts a given bit depth to an RMagick StorageType.
        #
        # @raise [ArgumentError] if given an unsupported bit depth
        # @param [Integer] bit_depth the bit depth of the pixel data
        # @return [Magick::CharPixel, Magick::ShortPixel] the proper storage type
        #
        def rm_data_type(bit_depth)
          return case bit_depth
          when 8
            Magick::CharPixel
          when 16
            Magick::ShortPixel
          else
            raise ArgumentError, "Unsupported bit depth: #{bit_depth}."
          end
        end

        # Converts a given DICOM photometry string to an RMagick pixel map string.
        #
        # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
        # @return [String] an RMagick pixel map string
        #
        def rm_map(photometry)
          raise ArgumentError, "Expected String, got #{photometry.class}." unless photometry.is_a?(String)
          if photometry.include?('COLOR') or photometry.include?('RGB')
            return 'RGB'
          elsif photometry.include?('YBR')
            return 'YBR'
          else
            return 'I' # (Assuming monochromeX - greyscale)
          end
        end

      end

    end
  end
end