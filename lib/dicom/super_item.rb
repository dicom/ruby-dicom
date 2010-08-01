#    Copyright 2008-2010 Christoffer Lervag

module DICOM

  # Super class which contains common code for both the DObject and Item classes.
  # This class includes the image related methods, since images may be stored either directly in the DObject,
  # or in items (encapsulated items in the "Pixel Data" element or in "Icon Image Sequence" items).
  #
  # === Inheritance
  #
  # As the SuperItem class inherits from the SuperParent class, all SuperParent methods are also available to objects which has inherited SuperItem.
  #
  class SuperItem < SuperParent

    # Checks if colored pixel data is present.
    # Returns true if it is, false if not.
    #
    def color?
      # "Photometric Interpretation" is contained in the data element "0028,0004":
      photometric = (self["0028,0004"].is_a?(DataElement) == true ? self["0028,0004"].value.upcase : "")
      if photometric.include?("COLOR") or photometric.include?("RGB") or photometric.include?("YBR")
        return true
      else
        return false
      end
    end

    # Checks if compressed pixel data is present.
    # Returns true if it is, false if not.
    #
    def compression?
      # If compression is used, the pixel data element is a Sequence (with encapsulated elements), instead of a DataElement:
      if self[PIXEL_TAG].is_a?(Sequence)
        return true
      else
        return false
      end
    end

    # Unpacks a binary pixel string and returns decoded pixel values in an array. Returns false if the decoding is unsuccesful.
    # The decode is performed using values defined in the image related data elements of the DObject instance.
    #
    # === Parameters
    #
    # * <tt>bin</tt> -- A binary String containing the pixels that will be decoded.
    # * <tt>stream</tt> -- A Stream instance to be used for decoding the pixels (optional).
    #
    def decode_pixels(bin, stream=@stream)
      pixels = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth_element = self["0028,0100"]
      pixel_representation_element = self["0028,0103"]
      if bit_depth_element and pixel_representation_element
        # Load the binary pixel data to the Stream instance:
        stream.set_string(bin)
        # Number of bytes used per pixel will determine how to unpack this:
        case bit_depth_element.value.to_i
          when 8
            pixels = stream.decode_all("BY") # Byte/Character/Fixnum (1 byte)
          when 16
            if pixel_representation_element.value.to_i == 1
              pixels = stream.decode_all("SS") # Signed short (2 bytes)
            else
              pixels = stream.decode_all("US") # Unsigned short (2 bytes)
            end
          when 12
            # 12 BIT SIMPLY NOT WORKING YET!
            # This one is a bit tricky to extract. I havent really given this priority so far as 12 bit image data is rather rare.
            raise "Decoding bit depth 12 is not implemented yet! Please contact the author (or edit the source code)."
          else
            raise "The Bit Depth #{bit_depth_element.value} has not received implementation in this procedure yet. Please contact the author (or edit the source code)."
        end
      else
        raise "The Data Element which specifies Bit Depth is missing. Unable to decode pixel data." unless bit_depth_element
        raise "The Data Element which specifies Pixel Representation is missing. Unable to decode pixel data." unless pixel_representation_element
      end
      return pixels
    end

    # Packs a pixel value array and returns an encoded binary string. Returns false if the encoding is unsuccesful.
    # The encoding is performed using values defined in the image related data elements of the DObject instance.
    #
    # === Parameters
    #
    # * <tt>pixels</tt> -- An array containing the pixel values that will be encoded.
    # * <tt>stream</tt> -- A Stream instance to be used for encoding the pixels (optional).
    #
    def encode_pixels(pixels, stream=@stream)
      bin = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth_element = self["0028,0100"]
      pixel_representation_element = self["0028,0103"]
      if bit_depth_element and pixel_representation_element
        # Number of bytes used per pixel will determine how to pack this:
        case bit_depth_element.value.to_i
          when 8
            bin = stream.encode(pixels, "BY") # Byte/Character/Fixnum (1 byte)
          when 16
            if pixel_representation_element.value.to_i == 1
              bin = stream.encode(pixels, "SS") # Signed short (2 bytes)
            else
              bin = stream.encode(pixels, "US") # Unsigned short (2 bytes)
            end
          when 12
            # 12 BIT SIMPLY NOT WORKING YET!
            # This one is a bit tricky to encode. I havent really given this priority so far as 12 bit image data is rather rare.
            raise "Encoding bit depth 12 is not implemented yet! Please contact the author (or edit the source code)."
          else
            raise "The Bit Depth #{bit_depth} has not received implementation in this procedure yet. Please contact the author (or edit the source code)."
        end
      else
        raise "The Data Element which specifies Bit Depth is missing. Unable to encode pixel data." unless bit_depth_element
        raise "The Data Element which specifies Pixel Representation is missing. Unable to encode pixel data." unless pixel_representation_element
      end
      return bin
    end

    # Returns the image pixel values in a standard Ruby Array.
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    #
    # === Notes
    #
    # * The returned array does not carry the dimensions of the pixel data: It is put in a one dimensional Array (vector).
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:rescale</tt> -- Boolean. If set as true, makes the method return processed, rescaled presentation values instead of the original, full pixel range.
    # * <tt>:narray</tt> -- Boolean. If set as true, forces the use of NArray instead of Ruby Array in the rescale process, for faster execution.
    #
    # === Examples
    #
    #   # Simply retrieve the pixel data:
    #   pixels = obj.get_image
    #   # Retrieve the pixel data rescaled to presentation values according to window center/width settings:
    #   pixels = obj.get_image(:rescale => true)
    #   # Retrieve the rescaled pixel data while using a numerical array in the rescaling process (~2 times faster):
    #   pixels = obj.get_image(:rescale => true, :narray => true)
    #
    def get_image(options={})
      if exists?(PIXEL_TAG)
        # For now we only support returning pixel data of the first frame, if the image is located in multiple pixel data items:
        if compression?
          pixels = decompress(image_strings.first)
        else
          pixels = decode_pixels(image_strings.first)
        end
        if pixels
          # Remap the image from pixel values to presentation values if the user has requested this:
          if options[:rescale]
            if options[:narray]
              # Use numerical array (faster):
              pixels = process_presentation_values_narray(pixels, -65535, 65535).to_a
            else
              # Use standard Ruby array (slower):
              pixels = process_presentation_values(pixels, -65535, 65535)
            end
          end
        else
          add_msg("Warning: Decompressing pixel values has failed. Array can not be filled.")
          pixels = false
        end
      else
        pixels = nil
      end
      return pixels
    end

    # Returns a RMagick image, created from the encoded pixel data using the image related data elements in the DObject instance.
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    #
    # === Notes
    #
    # * To call this method the user needs to have loaded the ImageMagick bindings in advance (require 'RMagick').
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:rescale</tt> -- Boolean. If set as true, makes the method return processed, rescaled presentation values instead of the original, full pixel range.
    # * <tt>:narray</tt> -- Boolean. If set as true, forces the use of NArray instead of RMagick/Ruby Array in the rescale process, for faster execution.
    #
    # === Examples
    #
    #   # Retrieve pixel data as RMagick object and display it:
    #   image = obj.get_image_magick
    #   image.display
    #   # Retrieve image object rescaled to presentation values according to window center/width settings:
    #   image = obj.get_image_magick(:rescale => true)
    #   # Retrieve rescaled image object while using a numerical array in the rescaling process (~2 times faster):
    #   images = obj.get_image_magick(:rescale => true, :narray => true)
    #
    def get_image_magick(options={})
      if exists?(PIXEL_TAG)
        unless color?
          # For now we only support returning pixel data of the first frame, if the image is located in multiple pixel data items:
          if compression?
            pixels = decompress(image_strings.first)
          else
            pixels = decode_pixels(image_strings.first)
          end
          if pixels
            rows, columns, frames = image_properties
            image = read_image_magick(pixels, columns, rows, frames, options)
            add_msg("Warning: Unfortunately, this method only supports reading the first image frame for 3D pixel data as of now.") if frames > 1
          else
            add_msg("Warning: Decompressing pixel values has failed. RMagick image can not be filled.")
            image = false
          end
        else
          add_msg("The DICOM object contains colored pixel data, which is not supported in this method yet.")
          image = false
        end
      else
        image = nil
      end
      return image
    end

    # Returns a 3-dimensional NArray object where the array dimensions corresponds to [frames, columns, rows].
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    #
    # === Notes
    #
    # * To call this method the user needs to loaded the NArray library in advance (require 'narray').
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:rescale</tt> -- Boolean. If set as true, makes the method return processed, rescaled presentation values instead of the original, full pixel range.
    #
    # === Examples
    #
    #   # Retrieve numerical pixel array:
    #   data = obj.get_image_narray
    #   # Retrieve numerical pixel array rescaled from the original pixel values to presentation values:
    #   data = obj.get_image_narray(:rescale => true)
    #
    def get_image_narray(options={})
      if exists?(PIXEL_TAG)
        unless color?
          # For now we only support returning pixel data of the first frame, if the image is located in multiple pixel data items:
          if compression?
            pixels = decompress(image_strings.first)
          else
            pixels = decode_pixels(image_strings.first)
          end
          if pixels
            # Decode the pixel values, then import to NArray  and give it the proper shape:
            rows, columns, frames = image_properties
            pixel_data = NArray.to_na(pixels).reshape!(frames, columns, rows)
            # Remap the image from pixel values to presentation values if the user has requested this:
            pixel_data = process_presentation_values_narray(pixel_data, -65535, 65535) if options[:rescale]
          else
            add_msg("Warning: Decompressing pixel values has failed. Numerical array can not be filled.")
            pixel_data = false
          end
        else
          add_msg("The DICOM object contains colored pixel data, which is not supported in this method yet.")
          pixel_data = false
        end
      else
        pixel_data = nil
      end
      return pixel_data
    end

    # Reads a binary string from a specified file and writes it to the value field of the pixel data element (7FE0,0010).
    #
    # === Parameters
    #
    # * <tt>file</tt> -- A string which specifies the path of the file containing pixel data.
    #
    # === Examples
    #
    #   obj.image_from_file("custom_image.bin")
    #
    def image_from_file(file)
      # Read and extract:
      f = File.new(file, "rb")
      bin = f.read(f.stat.size)
      if bin.length > 0
        # Write the binary data to the Pixel Data Element:
        set_pixels(bin)
      else
        add_msg("Notice: The specified file (#{file}) is empty. Nothing to store.")
      end
    end

    # Returns data related to the shape of the pixel data. The data is returned as three integers: rows, columns & number of frames.
    #
    # === Examples
    #
    #   rows, cols, frames = obj.image_properties
    #
    def image_properties
      row_element = self["0028,0010"]
      column_element = self["0028,0011"]
      frames = (self["0028,0008"].is_a?(DataElement) == true ? self["0028,0008"].value.to_i : 1)
      unless row_element and column_element
        raise "The Data Element which specifies Rows is missing. Unable to gather enough information to constuct an image." unless row_element
        raise "The Data Element which specifies Columns is missing. Unable to gather enough information to constuct an image." unless column_element
      else
        return row_element.value, column_element.value, frames
      end
    end

    # Dumps the binary content of the Pixel Data element to a file.
    #
    # === Parameters
    #
    # * <tt>file</tt> -- A string which specifies the file path to use when dumping the pixel data.
    #
    # === Examples
    #
    #   obj.image_to_file("exported_image.bin")
    #
    def image_to_file(file)
      # Get the binary image strings and dump them to file:
      images = image_strings
      images.each_index do |i|
        if images.length == 1
          f = File.new(file, "wb")
        else
          f = File.new("#{file}_#{i}", "wb")
        end
        f.write(images[i])
        f.close
      end
    end

    # Returns the pixel data binary string(s) of this parent in an array.
    # If no pixel data is present, returns an empty array.
    #
    def image_strings
      # Pixel data may be a single binary string in the pixel data element,
      # or located in several encapsulated item elements:
      pixel_element = self[PIXEL_TAG]
      strings = Array.new
      if pixel_element.is_a?(DataElement)
        strings << pixel_element.bin
      elsif pixel_element.is_a?(Sequence)
        pixel_items = pixel_element.children.first.children
        pixel_items.each do |item|
          strings << item.bin
        end
      end
      return strings
    end

    # Removes all Sequence elements from the DObject or Item instance.
    #
    def remove_sequences
      @tags.each_value do |element|
        remove(element.tag) if element.is_a?(Sequence)
      end
    end

    # Encodes pixel data from a Ruby Array and writes it to the pixel data element (7FE0,0010).
    #
    # === Parameters
    #
    # * <tt>pixels</tt> -- An array of pixel values (integers).
    #
    def set_image(pixels)
      if pixels.is_a?(Array)
        # Encode the pixel data:
        bin = encode_pixels(pixels)
        # Write the binary data to the Pixel Data Element:
        set_pixels(bin)
      else
        raise "Unexpected object type (#{pixels.class}) for the pixels parameter. Array was expected."
      end
    end

    # Encodes pixel data from a RMagick image object and writes it to the pixel data element (7FE0,0010).
    #
    # === Restrictions
    #
    # If pixel value rescaling is wanted, BOTH <b>:min</b> and <b>:max</b> must be set!
    #
    # Because of rescaling when importing pixel values to a RMagick object, and the possible
    # difference between presentation values and pixel values, the use of set_image_magick() may
    # result in pixel data that differs from what is expected. This method must be used with care!
    #
    # === Options
    #
    # * <tt>:max</tt> -- Fixnum. Pixel values will be rescaled using this as the new maximum value.
    # * <tt>:min</tt> -- Fixnum. Pixel values will be rescaled using this as the new minimum value.
    #
    # === Examples
    #
    #   # Encode an image object while requesting that only a specific pixel value range is used:
    #   obj.set_image_magick(my_image, :min => -2000, :max => 3000)
    #
    def set_image_magick(magick_image, options={})
      # Export the RMagick object to a standard Ruby Array:
      pixels = magick_image.export_pixels(x=0, y=0, columns=magick_image.columns, rows=magick_image.rows, map="I")
      # Rescale pixel values?
      if options[:min] and options[:max]
        p_min = pixels.min
        p_max = pixels.max
        if p_min != options[:min] or p_max != options[:max]
          wanted_range = options[:max] - options[:min]
          factor = wanted_range.to_f/(pixels.max - pixels.min).to_f
          offset = pixels.min - options[:min]
          pixels.collect!{|x| ((x*factor)-offset).round}
        end
      end
      # Encode and write to the Pixel Data Element:
      set_image(pixels)
    end

    # Encodes pixel data from a NArray and writes it to the pixel data element (7FE0,0010).
    #
    # === Restrictions
    #
    # * If pixel value rescaling is wanted, BOTH <b>:min</b> and <b>:max</b> must be set!
    #
    # === Options
    #
    # * <tt>:max</tt> -- Fixnum. Pixel values will be rescaled using this as the new maximum value.
    # * <tt>:min</tt> -- Fixnum. Pixel values will be rescaled using this as the new minimum value.
    #
    # === Examples
    #
    #   # Encode a numerical pixel array while requesting that only a specific pixel value range is used:
    #   obj.set_image_narray(pixels, :min => -2000, :max => 3000)
    #
    def set_image_narray(narray, options={})
      # Rescale pixel values?
      if options[:min] and options[:max]
        n_min = narray.min
        n_max = narray.max
        if n_min != options[:min] or n_max != options[:max]
          wanted_range = options[:max] - options[:min]
          factor = wanted_range.to_f/(n_max - n_min).to_f
          offset = n_min - options[:min]
          narray = narray*factor-offset
        end
      end
      # Export the NArray object to a standard Ruby Array:
      pixels = narray.to_a.flatten!
      # Encode and write to the Pixel Data Element:
      set_image(pixels)
    end


    # Following methods are private:
    private


    # Attempts to decompress compressed pixel data.
    # If successful, returns the pixel data in a Ruby Array. If not, returns false.
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
    # * <tt>string</tt> -- A binary string which has been extracted from the pixel data element of the DICOM object.
    #
    def decompress(string)
      pixels = false
      # We attempt to decompress the pixels using RMagick (ImageMagick):
      begin
        image = Magick::Image.from_blob(string)
        if color?
          pixels = image.export_pixels(0, 0, image.columns, image.rows, "RGB")
        else
          pixels = image.export_pixels(0, 0, image.columns, image.rows, "I")
        end
      rescue
        add_msg("Warning: Decoding the compressed image data from this DICOM object was NOT successful!")
      end
      return image
    end


    # Converts original pixel data values to presentation values, which are returned.
    #
    # === Parameters
    #
    # * <tt>pixel_data</tt> -- An array of pixel values (integers).
    # * <tt>min_allowed</tt> -- Fixnum. The minimum value allowed for the returned pixels.
    # * <tt>max_allowed</tt> -- Fixnum. The maximum value allowed for the returned pixels.
    #
    def process_presentation_values(pixel_data, min_allowed, max_allowed)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
      # PixelOutput = slope * pixel_values + intercept
      if intercept != 0 or slope != 1
        pixel_data.collect!{|x| (slope * x) + intercept}
      end
      # Contrast enhancement by black and white thresholding:
      if center and width
        low = center - width/2
        high = center + width/2
        pixel_data.each_index do |i|
          if pixel_data[i] < low
            pixel_data[i] = low
          elsif pixel_data[i] > high
            pixel_data[i] = high
          end
        end
      end
      # Need to introduce an offset?
      min_pixel_value = pixel_data.min
      if min_allowed
        if min_pixel_value < min_allowed
          offset = min_pixel_value.abs
          pixel_data.collect!{|x| x + offset}
        end
      end
      # Downscale pixel range?
      max_pixel_value = pixel_data.max
      if max_allowed
        if max_pixel_value > max_allowed
          factor = (max_pixel_value.to_f/max_allowed.to_f).ceil
          pixel_data.collect!{|x| x / factor}
        end
      end
      return pixel_data
    end

    # Converts original pixel data values to a RMagick image object containing presentation values.
    # Returns the RMagick image object.
    #
    # === Parameters
    #
    # * <tt>pixel_data</tt> -- An array of pixel values (integers).
    # * <tt>max_allowed</tt> -- Fixnum. The maximum value allowed for the returned pixels.
    # * <tt>columns</tt> -- Fixnum. Number of columns in the image to be created.
    # * <tt>rows</tt> -- Fixnum. Number of rows in the image to be created.
    #
    def process_presentation_values_magick(pixel_data, max_allowed, columns, rows)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
      # PixelOutput = slope * pixel_values + intercept
      if intercept != 0 or slope != 1
        pixel_data.collect!{|x| (slope * x) + intercept}
      end
      # Need to introduce an offset?
      offset = 0
      min_pixel_value = pixel_data.min
      if min_pixel_value < 0
        offset = min_pixel_value.abs
        pixel_data.collect!{|x| x + offset}
      end
      # Downscale pixel range?
      factor = 1
      max_pixel_value = pixel_data.max
      if max_allowed
        if max_pixel_value > max_allowed
          factor = (max_pixel_value.to_f/max_allowed.to_f).ceil
          pixel_data.collect!{|x| x / factor}
        end
      end
      image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
      # Contrast enhancement by black and white thresholding:
      if center and width
        low = (center - width/2 + offset) / factor
        high = (center + width/2 + offset) / factor
        image = image.level(low, high)
      end
      return image
    end

    # Converts original pixel data values to presentation values, using the efficient NArray library.
    #
    # === Notes
    #
    # * If a Ruby Array is supplied, the method returns a one-dimensional NArray object (i.e. no columns & rows).
    # * If a NArray is supplied, the NArray is returned with its original dimensions.
    #
    # === Parameters
    #
    # * <tt>pixel_data</tt> -- An Array/NArray of pixel values (integers).
    # * <tt>min_allowed</tt> -- Fixnum. The minimum value allowed for the returned pixels.
    # * <tt>max_allowed</tt> -- Fixnum. The maximum value allowed for the returned pixels.
    #
    def process_presentation_values_narray(pixel_data, min_allowed, max_allowed)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
      # Need to convert to NArray?
      if pixel_data.is_a?(Array)
        n_arr = NArray.to_na(pixel_data)
      else
        n_arr = pixel_data
      end
      # Rescale:
      # PixelOutput = slope * pixel_values + intercept
      if intercept != 0 or slope != 1
        n_arr = slope * n_arr + intercept
      end
      # Contrast enhancement by black and white thresholding:
      if center and width
        low = center - width/2
        high = center + width/2
        n_arr[n_arr < low] = low
        n_arr[n_arr > high] = high
      end
      # Need to introduce an offset?
      min_pixel_value = n_arr.min
      if min_allowed
        if min_pixel_value < min_allowed
          offset = min_pixel_value.abs
          n_arr = n_arr + offset
        end
      end
      # Downscale pixel range?
      max_pixel_value = n_arr.max
      if max_allowed
        if max_pixel_value > max_allowed
          factor = (max_pixel_value.to_f/max_allowed.to_f).ceil
          n_arr = n_arr / factor
        end
      end
      return n_arr
    end

    # Creates a RMagick image object from the specified pixel value array, and returns this image.
    #
    # === Restrictions
    #
    # Reading compressed data has been removed for now as it never seemed to work on any of the samples.
    # Hopefully, a more robust solution will be found and included in a future version.
    # Tests with RMagick can be tried with something like:
    #   image = Magick::Image.from_blob(element.bin)
    #
    def read_image_magick(pixel_data, columns, rows, frames, options={})
      # Remap the image from pixel values to presentation values if the user has requested this:
      if options[:rescale] == true
        # What tools will be used to process the pixel presentation values?
        if options[:narray] == true
          # Use numerical array (fast):
          pixel_data = process_presentation_values_narray(pixel_data, 0, Magick::QuantumRange).to_a
          image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
        else
          # Use a combination of ruby array and RMagick processing:
          image = process_presentation_values_magick(pixel_data, Magick::QuantumRange, columns, rows)
        end
      else
        # Load original pixel values to a RMagick object:
        image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
      end
      return image
    end

    # Transfers a pre-encoded binary string to the pixel data element, either by overwriting the existing
    # element value, or creating a new one DataElement.
    #
    def set_pixels(bin)
      if self.exists?(PIXEL_TAG)
        # Update existing Data Element:
        self[PIXEL_TAG].bin = bin
      else
        # Create new Data Element:
        pixel_element = DataElement.new(PIXEL_TAG, bin, :encoded => true, :parent => self)
      end
    end

    # Gathers and returns the window level values needed to convert the original pixel values to presentation values.
    #
    # === Notes
    #
    # If some of these values are missing in the DObject instance, default values are used instead
    # for intercept and slope, while center and width are set to nil. No errors are raised.
    #
    def window_level_values
      center = (self["0028,1050"].is_a?(DataElement) == true ? self["0028,1050"].value.to_i : nil)
      width = (self["0028,1051"].is_a?(DataElement) == true ? self["0028,1051"].value.to_i : nil)
      intercept = (self["0028,1052"].is_a?(DataElement) == true ? self["0028,1052"].value.to_i : 0)
      slope = (self["0028,1053"].is_a?(DataElement) == true ? self["0028,1053"].value.to_i : 1)
      return center, width, intercept, slope
    end

  end
end