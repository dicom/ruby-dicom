module DICOM

  # This module is the general interface between the ImageItem class and the
  # image methods found in the specific image processor modules.
  #
  module ImageProcessor

    # Creates image objects from one or more compressed, binary string blobs.
    #
    # @param [Array<String>, String] blobs binary string blob(s) containing compressed pixel data
    # @return [Array<MagickImage>, FalseClass] - an array of images, or false (if decompression failed)
    #
    def decompress(blobs)
      raise ArgumentError, "Expected Array or String, got #{blobs.class}." unless [String, Array].include?(blobs.class)
      blobs = [blobs] unless blobs.is_a?(Array)
      begin
        return image_module.decompress(blobs)
      rescue
        return false
      end
    end

    # Extracts an array of pixels (integers) from an image object.
    #
    # @param [MagickImage] image a Magick image object
    # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
    # @return [Array<Integer>] an array of pixel values
    #
    def export_pixels(image, photometry)
      raise ArgumentError, "Expected String, got #{photometry.class}." unless photometry.is_a?(String)
      image_module.export_pixels(image, photometry)
    end

    # Creates an image object from a binary string blob.
    #
    # @param [String] blob binary string blob containing pixel data
    # @param [Integer] columns the number of columns
    # @param [Integer] rows the number of rows
    # @param [Integer] depth the bit depth of the encoded pixel data
    # @param [String] photometry a code describing the photometry of the pixel data (e.g. 'MONOCHROME1' or 'COLOR')
    # @return [MagickImage] a Magick image object
    #
    def import_pixels(blob, columns, rows, depth, photometry)
      raise ArgumentError, "Expected String, got #{blob.class}." unless blob.is_a?(String)
      image_module.import_pixels(blob, columns, rows, depth, photometry)
    end

    # Gives an array containing the image objects that are supported by the image processor.
    #
    # @return [Array<String>] the valid image classes
    #
    def valid_image_objects
      return ['Magick::Image', 'MiniMagick::Image']
    end


    private


    # Gives the specific image processor module corresponding to the specified
    # image_processor module option.
    #
    # @raise [RuntimeError] if an unknown image processor is specified
    # @return [DcmMiniMagick, DcmRMagick] the image processor module to be used
    #
    def image_module
      case DICOM.image_processor
      when :mini_magick
        require 'mini_magick'
        DcmMiniMagick
      when :rmagick
        require 'rmagick'
        DcmRMagick
      else
        raise "Uknown image processor #{DICOM.image_processor}"
      end
    end

  end
end