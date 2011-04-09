module DICOM
  module ImageProcessor

    # Creates image objects from one or more compressed, binary string blobs.
    # Returns an array of images. If decompression fails, returns false.
    #
    # === Parameters
    #
    # * <tt>blobs</tt> -- Binary string blob(s) containing compressed pixel data.
    #
    def decompress(blobs)
      raise ArgumentError, "Expected Array or String, got #{blobs.class}." unless [String, Array].includes?(blobs.class)
      blobs = [blobs] unless blobs.is_a?(Array)
      image_module.decompress(blobs)
    end

    # Creates an image object from a binary string blob.
    #
    # === Parameters
    #
    # * <tt>blob</tt> -- Binary string blob containing raw pixel data.
    # * <tt>columns</tt> -- Number of columns.
    # * <tt>rows</tt> -- Number of rows.
    # * <tt>depth</tt> -- Bit depth of the encoded pixel data.
    # * <tt>photometry</tt> -- String describing the DICOM photometry of the pixel data. Example: 'MONOCHROME1', 'RGB'.
    #
    def import_pixels(blob, columns, rows, depth, photometry)
      raise ArgumentError, "Expected String, got #{blob.class}." unless blob.is_a?(String)
      image_module.import_pixels(blob, columns, rows, depth, photometry)
    end


    private


    def image_module
      case DICOM.image_processor
      when :mini_magick
        DcmMiniMagick
      when :rmagick
        DcmRMagick
      else
        raise "Uknown image processor #{DICOM.image_processor}"
      end
    end

  end
end