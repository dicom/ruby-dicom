#    Copyright 2010 Christoffer Lervag

module DICOM

  # Super class which contains code that is common for both the DObject and Item classes.
  # This class contains image methods, since images may be stored in either the DObject, in encapsulated Items or in Icon Image Sequence Items.
  class SuperItem < SuperParent

    # Unpacks and returns pixel values in an Array from the specified binary string. The decode is based on attributes defined in the DObject.
    # Returns false if decode is unsuccesful.
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
    
    # Encodes a pixel array based on attributes defined in the DObject and returns the resulting binary string.
    # Returns false if encode is unsuccesful.
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

    # Returns the image pixel data in a standard Ruby array.
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    # The returned array does not carry the dimensions of the pixel data: It will be a one dimensional array (vector).
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    # :narray => true  - Performs the rescale process with NArray instead of Ruby Array, which is faster.
    def get_image(options={})
      pixel_data_element = self[PIXEL_TAG]
      if pixel_data_element
        # For now we only support returning pixel data if the image is located in a single pixel data element:
        if pixel_data_element.is_a?(DataElement)
          pixels = decode_pixels(pixel_data_element.bin)
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
          add_msg("Warning: Method get_image() does not currently support returning pixel data from encapsulated images.")
          pixels = false
        end
      else
        pixels = nil
      end
      return pixels
    end

    # Returns a RMagick image, built from the pixel data and image information in the DICOM object.
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    # To call this method the user needs to have loaded the ImageMagick library in advance (require 'RMagick').
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    # :narray => true  - Use NArray when rescaling pixel values (faster than using RMagick/Ruby array).
    def get_image_magick(options={})
      color = (self["0028,0004"].is_a?(DataElement) == true ? self["0028,0004"].value : "")
      pixel_data_element = self[PIXEL_TAG]
      if pixel_data_element
        # For now we only support returning pixel data if the image is located in a single pixel data element:
        if pixel_data_element.is_a?(DataElement)
          if color.upcase.include?("MONOCHROME")
            # Creating a NArray object using int to make sure we have the necessary range for our numbers:
            rows, columns, frames = image_properties
            pixels = decode_pixels(pixel_data_element.bin)
            image = read_image_magick(pixels, columns, rows, frames, options)
            add_msg("Warning: Unfortunately, this method only supports reading the first image frame for 3D pixel data as of now.") if frames > 1
          else
            add_msg("Warning: Either Photomtetric Interpretation is missing, or the DICOM object contains pixel data with colors, which is unsupported as of yet.")
            image = false
          end
        else
          add_msg("Warning: Method get_image_magick() does not currently support returning pixel data from encapsulated images.")
          image = false
        end
      else
        image = nil
      end
      return image
    end

    # Returns a 3d NArray object where the array dimensions corresponds to [frames, columns, rows].
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    # To call this method the user needs to loaded the NArray library in advance (require 'narray').
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    def get_image_narray(options={})
      color = (self["0028,0004"].is_a?(DataElement) == true ? self["0028,0004"].value : "")
      pixel_data_element = self[PIXEL_TAG]
      if pixel_data_element
        # For now we only support returning pixel data if the image is located in a single pixel data element:
        if pixel_data_element.is_a?(DataElement)
          if color.upcase.include?("MONOCHROME")
            # Creating a NArray object using int to make sure we have the necessary range for our numbers:
            rows, columns, frames = image_properties
            pixel_data = NArray.int(frames,columns,rows)
            pixel_frame = NArray.int(columns,rows)
            pixels = decode_pixels(pixel_data_element.bin)
            # Read frame by frame:
            frames.times do |i|
              (columns*rows).times do |j|
                pixel_frame[j] = pixels[j+i*columns*rows]
              end
              pixel_data[i, true, true] = pixel_frame
            end
            # Remap the image from pixel values to presentation values if the user has requested this:
            pixel_data = process_presentation_values_narray(pixel_data, -65535, 65535) if options[:rescale]
          else
            add_msg("Warning: Either Photomtetric Interpretation is missing, or the DICOM object contains pixel data with colors, which is unsupported as of yet.")
            pixel_data = false
          end
        else
          add_msg("Warning: Method get_image_narray() does not currently support returning pixel data from encapsulated images.")
          pixel_data = false
        end
      else
        pixel_data = nil
      end
      return pixel_data
    end

    # Reads a binary string from the specified file and writes it to the Pixel Data Element.
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

    # Returns data regarding the geometrical properties of the pixel data: rows, columns & number of frames.
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

    # Dumps the binary content of the Pixel Data element to file.
    def image_to_file(file)
      pixel_element = self[PIXEL_TAG]
      pixel_data = Array.new
      if pixel_element
        # Pixel data may be a single binary string, or located in several item elements:
        if pixel_element.is_a?(DataElement)
          pixel_data << pixel_element.bin
        else
          pixel_items = pixel_element.children.first.children
          pixel_items.each do |item|
            pixel_data << item.bin
          end
        end
        pixel_data.each_index do |i|
          if pixel_data.length == 1
            f = File.new(file, "wb")
          else
            f = File.new("#{file}_#{i}", "wb")
          end
          f.write(pixel_data[i])
          f.close
        end
      end
    end

    # Removes all sequences from the DObject/Item.
    def remove_sequences
      @tags.each_value do |element|
        remove(element.tag) if element.is_a?(Sequence)
      end
    end

    # Handles pixel data from a Ruby Array, encodes it and writes it to the Pixel Data Element.
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

    # Handles pixel data from a RMagick image object, encodes it and writes it to the Pixel Data Element.
    # NB: If value rescaling is wanted, both :min and :max must be set!
    # NB! Because of rescaling when importing pixel values to a RMagick object, and the possible
    # difference between presentation values and pixel values, the use of set_image_magick() may
    # result in pixel data that differs from what is expected. This method must be used with great care!
    # Options:
    # :max => value  - Pixel values will be rescaled using this as the new maximum value.
    # :min => value  - Pixel values will be rescaled, using this as the new minimum value.
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

    # Handles pixel data from a Numerical Array (NArray), encodes it and writes it to the Pixel Data Element.
    # NB: If value rescaling is wanted, both :min and :max must be set!
    # Options:
    # :max => value  - Pixel values will be rescaled using this as the new maximum value.
    # :min => value  - Pixel values will be rescaled, using this as the new minimum value.
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


    # Converts original pixel data values to presentation values.
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

    # Converts original pixel data values to presentation values, using the faster numerical array.
    # If a Ruby array is supplied, this returns a one-dimensional NArray object (i.e. no columns & rows).
    # If a NArray is supplied, the NArray is returned with its original dimensions.
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

    # Returns one or more RMagick image objects from the binary string pixel data,
    # performing decompression of data if necessary.
    # Reading compressed data has been removed for now as it never seemed to work on any of the samples.
    # Tested with RMagick and something like: image = Magick::Image.from_blob(element.bin)
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

    # Transfers a pre-encoded binary string to the Pixel Data Element, either by updating an existing one, or creating a new one.
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
    # If some of these values are missing in the DICOM object, default values are used instead
    # for intercept and slope, while center and width are set to nil. No errors are raised.
    def window_level_values
      center = (self["0028,1050"].is_a?(DataElement) == true ? self["0028,1050"].value.to_i : nil)
      width = (self["0028,1051"].is_a?(DataElement) == true ? self["0028,1051"].value.to_i : nil)
      intercept = (self["0028,1052"].is_a?(DataElement) == true ? self["0028,1052"].value.to_i : 0)
      slope = (self["0028,1053"].is_a?(DataElement) == true ? self["0028,1053"].value.to_i : 1)
      return center, width, intercept, slope
    end

  end # of class
end # of module