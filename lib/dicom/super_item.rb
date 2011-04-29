#    Copyright 2008-2011 Christoffer Lervag

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

    include ImageProcessor

    # Checks if colored pixel data is present.
    # Returns true if it is, false if not.
    #
    def color?
      # "Photometric Interpretation" is contained in the data element "0028,0004":
      begin
        photometric = photometry
        if photometric.include?("COLOR") or photometric.include?("RGB") or photometric.include?("YBR")
          return true
        else
          return false
        end
      rescue
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

    # Unpacks a binary pixel string and returns decoded pixel values in an array.
    # The decode is performed using values defined in the image related data elements of the DObject instance.
    #
    # === Parameters
    #
    # * <tt>bin</tt> -- A binary String containing the pixels that will be decoded.
    # * <tt>stream</tt> -- A Stream instance to be used for decoding the pixels (optional).
    #
    def decode_pixels(bin, stream=@stream)
      raise ArgumentError, "Expected String, got #{bin.class}." unless bin.is_a?(String)
      pixels = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth_element = self["0028,0100"]
      pixel_representation_element = self["0028,0103"]
      if bit_depth_element and pixel_representation_element
        # Load the binary pixel data to the Stream instance:
        stream.set_string(bin)
        template = template_string(bit_depth_element.value.to_i)
        pixels = stream.decode_all(template) if template
      else
        raise "The Data Element which specifies Bit Depth is missing. Unable to decode pixel data." unless bit_depth_element
        raise "The Data Element which specifies Pixel Representation is missing. Unable to decode pixel data." unless pixel_representation_element
      end
      return pixels
    end

    # Packs a pixel value array and returns an encoded binary string.
    # The encoding is performed using values defined in the image related data elements of the DObject instance.
    #
    # === Parameters
    #
    # * <tt>pixels</tt> -- An array containing the pixel values that will be encoded.
    # * <tt>stream</tt> -- A Stream instance to be used for encoding the pixels (optional).
    #
    def encode_pixels(pixels, stream=@stream)
      raise ArgumentError, "Expected Array, got #{pixels.class}." unless pixels.is_a?(Array)
      bin = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth_element = self["0028,0100"]
      pixel_representation_element = self["0028,0103"]
      if bit_depth_element and pixel_representation_element
        template = template_string(bit_depth_element.value.to_i)
        bin = stream.encode(pixels, template) if template
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
    # * <tt>:level</tt> -- Boolean or array. If set as true window leveling is performed using default values from the DICOM object. If an array ([center, width]) is specified, these custom values are used instead.
    # * <tt>:narray</tt> -- Boolean. If set as true, forces the use of NArray for the pixel remap process (for faster execution).
    # * <tt>:remap</tt> -- Boolean. If set as true, the returned pixel values are remapped to presentation values.
    #
    # === Examples
    #
    #   # Simply retrieve the pixel data:
    #   pixels = obj.get_image
    #   # Retrieve the pixel data remapped to presentation values according to window center/width settings:
    #   pixels = obj.get_image(:remap => true)
    #   # Retrieve the remapped pixel data while using numerical array (~twice as fast):
    #   pixels = obj.get_image(:remap => true, :narray => true)
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
          if options[:remap] or options[:level]
            if options[:narray]
              # Use numerical array (faster):
              pixels = process_presentation_values_narray(pixels, -65535, 65535, options[:level]).to_a
            else
              # Use standard Ruby array (slower):
              pixels = process_presentation_values(pixels, -65535, 65535, options[:level])
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

    # Returns a single image object, created from the encoded pixel data using the image related data elements in the DICOM object.
    # If the object contains multiple image frames, the first image frame is returned, unless the :frame option is used.
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    #
    # === Notes
    #
    # * Returns an image object in accordance with the selected image processor. Available processors are :rmagick and :mini_magick.
    # * When calling this method the corresponding image processor gem must have been loaded in advance (example: require 'RMagick').
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:frame</tt> -- Fixnum. For DICOM objects containing multiple frames, this option can be used to extract a specific image frame. Defaults to 0.
    # * <tt>:level</tt> -- Boolean or array. If set as true window leveling is performed using default values from the DICOM object. If an array ([center, width]) is specified, these custom values are used instead.
    # * <tt>:narray</tt> -- Boolean. If set as true, forces the use of NArray for the pixel remap process (for faster execution).
    # * <tt>:remap</tt> -- Boolean. If set as true, the returned pixel values are remapped to presentation values.
    #
    # === Examples
    #
    #   # Retrieve pixel data as an RMagick image object and display it:
    #   image = obj.get_image_magick
    #   image.display
    #   # Retrieve frame 5 in the pixel data:
    #   image = obj.get_image_magick(:frame => 5)
    #
    def get_image_magick(options={})
      options[:frame] = options[:frame] || 0
      return get_images_magick(options)
    end

    # Returns an array of image objects, created from the encoded pixel data using the image related data elements in the DICOM object.
    # Returns an empty array if no data is present, or if it fails to retrieve pixel data which is present.
    #
    # === Notes
    #
    # * Returns an array of image objects in accordance with the selected image processor. Available processors are :rmagick and :mini_magick.
    # * When calling this method the corresponding image processor gem must have been loaded in advance (example: require 'RMagick').
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:frame</tt> -- Fixnum. Returns only an image object from the specified frame.
    # * <tt>:level</tt> -- Boolean or array. If set as true window leveling is performed using default values from the DICOM object. If an array ([center, width]) is specified, these custom values are used instead.
    # * <tt>:narray</tt> -- Boolean. If set as true, forces the use of NArray for the pixel remap process (for faster execution).
    # * <tt>:remap</tt> -- Boolean. If set as true, the returned pixel values are remapped to presentation values.
    #
    # === Examples
    #
    #   # Retrieve the pixel data as RMagick image objects:
    #   images = obj.get_images_magick
    #   # Retrieve the pixel data as RMagick image objects, remapped to presentation values (but without any leveling):
    #   images = obj.get_images_magick(:remap => true)
    #   # Retrieve the pixel data as RMagick image objects, remapped to presentation values and leveled using the default center/width values in the DICOM object:
    #   images = obj.get_images_magick(:level => true)
    #   # Retrieve the pixel data as RMagick image objects, remapped to presentation values, leveled with the specified center/width values and using numerical array for the rescaling (~twice as fast).
    #   images = obj.get_images_magick(:level => [-200,1000], :narray => true)
    #
    def get_images_magick(options={})
      if exists?(PIXEL_TAG)
        # Gather the necessary image data, and extract the frame of interest if indicated:
        rows, columns, frames = image_properties
        strings = image_strings(true)
        strings = [strings[options[:frame]]] if options[:frame]
        if compression?
          # Decompress, either to numbers (RLE) or to an image object (image based compressions):
          if [TXS_RLE].include?(transfer_syntax)
            pixel_frames = Array.new
            strings.each {|string| pixel_frames << decode_rle(columns, rows, string)}
          else
            images = decompress(strings)
            add_msg("Warning: Decompressing pixel values has failed (unsupported transfer syntax: '#{transfer_syntax}')") unless images
          end
        else
          # Uncompressed: Decode to numbers.
          pixel_frames = Array.new
          strings.each {|string| pixel_frames << decode_pixels(string)}
        end
        if pixel_frames
          images = Array.new
          pixel_frames.each do |pixels|
            # Pixel values and pixel order may need to be rearranged if we have color data:
            pixels = process_colors(pixels) if color?
            if pixels
              image = read_image(pixels, columns, rows, options)
            else
              add_msg("Warning: Processing pixel values for this particular color mode failed, unable to construct image(s).")
              image = false
            end
            images << image if image
          end
        else
          images = false unless images
        end
      else
        images = nil
      end
      # Return specific frame or array with all images?
      if options[:frame]
        # Return image object (if success) or false/nil on failure:
        if images
          return images.first
        else
          return images
        end
      else
        # Return array of image objects or an empty array if decoding images failed.
        images = Array.new unless images
        return images
      end
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
    # * <tt>:level</tt> -- Boolean or array. If set as true window leveling is performed using default values from the DICOM object. If an array ([center, width]) is specified, these custom values are used instead.
    # * <tt>:remap</tt> -- Boolean.  If set as true, the returned pixel values are remapped to presentation values.
    #
    # === Examples
    #
    #   # Retrieve numerical pixel array:
    #   data = obj.get_image_narray
    #   # Retrieve numerical pixel array remapped from the original pixel values to presentation values:
    #   data = obj.get_image_narray(:remap => true)
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
            pixel_data = process_presentation_values_narray(pixel_data, -65535, 65535, options[:level]) if options[:remap] or options[:level]
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
    #   obj.image_from_file("custom_image.dat")
    #
    def image_from_file(file)
      raise ArgumentError, "Expected #{String}, got #{file.class}." unless file.is_a?(String)
      f = File.new(file, "rb")
      bin = f.read(f.stat.size)
      if bin.length > 0
        # Write the binary data to the Pixel Data Element:
        write_pixels(bin)
      else
        add_msg("Notice: The specified file (#{file}) is empty. Nothing to transfer.")
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

    # Returns the pixel data binary string(s) in an array.
    # If no pixel data is present, returns an empty array.
    #
    # === Parameters
    #
    # * <tt>split</tt> -- Boolean. If true, a pixel data string containing 3d volumetric data will be split into N substrings, where N equals the number of frames.
    #
    def image_strings(split=false)
      # Pixel data may be a single binary string in the pixel data element,
      # or located in several encapsulated item elements:
      pixel_element = self[PIXEL_TAG]
      strings = Array.new
      if pixel_element.is_a?(DataElement)
        if split
          rows, columns, frames = image_properties
          strings = pixel_element.bin.dup.divide(frames)
        else
          strings << pixel_element.bin
        end
      elsif pixel_element.is_a?(Sequence)
        pixel_items = pixel_element.children.first.children
        pixel_items.each {|item| strings << item.bin}
      end
      return strings
    end

    # Dumps the binary content of the Pixel Data element to the specified file.
    #
    # === Notes
    #
    # * If the DICOM object contains multi-fragment pixel data, each fragment will be dumped to separate files (e.q. 'fragment-0.dat', 'fragment-1.dat').
    #
    # === Parameters
    #
    # * <tt>file</tt> -- A string which specifies the file path to use when dumping the pixel data.
    #
    # === Examples
    #
    #   obj.image_to_file("exported_image.dat")
    #
    def image_to_file(file)
      raise ArgumentError, "Expected #{String}, got #{file.class}." unless file.is_a?(String)
      # Split the file name in case of multiple fragments:
      parts = file.split('.')
      if parts.length > 1
        base = parts[0..-2].join
        extension = "." + parts.last
      else
        base = file
        extension = ""
      end
      # Get the binary image strings and dump them to the file(s):
      images = image_strings
      images.each_index do |i|
        if images.length == 1
          f = File.new(file, "wb")
        else
          f = File.new("#{base}-#{i}#{extension}", "wb")
        end
        f.write(images[i])
        f.close
      end
    end

    def num_cols
      self["0028,0011"].value rescue nil
    end

    def num_frames
      (self["0028,0008"].is_a?(DataElement) == true ? self["0028,0008"].value.to_i : 1)
    end

    def num_rows
      self["0028,0010"].value rescue nil
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
      raise ArgumentError, "Expected Array, got #{pixels.class}." unless pixels.is_a?(Array)
      # Encode the pixel data:
      bin = encode_pixels(pixels)
      # Write the binary data to the Pixel Data Element:
      write_pixels(bin)
    end

    # Encodes pixel data from a (Magick) image object and writes it to the pixel data element (7FE0,0010).
    #
    # === Restrictions
    #
    # If pixel value rescaling is wanted, BOTH <b>:min</b> and <b>:max</b> must be set!
    #
    # Because of pixel value issues related to image objects (images dont like signed integers), and the possible
    # difference between presentation values and raw pixel values, the use of set_image_magick() may
    # result in pixel data where the integer values differs somewhat from what is expected. Use with care!
    # For precise pixel value processing, use the Array and NArray based pixel data methods instead.
    #
    # === Options
    #
    # * <tt>:max</tt> -- Integer. Pixel values will be rescaled using this as the new maximum value.
    # * <tt>:min</tt> -- Integer. Pixel values will be rescaled using this as the new minimum value.
    #
    # === Examples
    #
    #   # Encode an image object while requesting that only a specific pixel value range is used:
    #   obj.set_image_magick(my_image, :min => -2000, :max => 3000)
    #
    def set_image_magick(image, options={})
      raise ArgumentError, "Expected one of the supported image objects (#{valid_image_objects}), got #{image.class}." unless valid_image_objects.include?(image.class)
      # Export to pixels using the proper image processor:
      pixels = export_pixels(image, photometry)
      # Rescale pixel values?
      if options[:min] and options[:max]
        p_min = pixels.min
        p_max = pixels.max
        if p_min != options[:min] or p_max != options[:max]
          wanted_range = options[:max] - options[:min]
          factor = wanted_range.to_f/(pixels.max - pixels.min).to_f
          offset = pixels.min - options[:min]
          pixels.collect! {|x| ((x*factor)-offset).round}
        end
      end
      # Encode and write to the Pixel Data Element:
      set_image(pixels)
    end

    # Encodes pixel data from an NArray and writes it to the pixel data element (7FE0,0010).
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
      raise ArgumentError, "Expected NArray, got #{narray.class}." unless narray.is_a?(NArray)
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
      pixels = narray.to_a.flatten
      # Encode and write to the Pixel Data Element:
      set_image(pixels)
    end


    # Following methods are private:
    private

    # Returns the effective bit depth of the pixel data (considers a special case for Palette colored images).
    #
    def actual_bit_depth
      raise "The 'Bits Allocated' DataElement is missing from this DICOM instance. Unable to encode/decode pixel data." unless exists?("0028,0100")
      if photometry == PI_PALETTE_COLOR
      # Only one channel is checked and it is assumed that all channels have the same number of bits.
        return self["0028,1101"].value.split("\\").last.to_i
      else
        return bit_depth
      end
    end


    # Returns the value from the "Bits Allocated" DataElement.
    #
    def bit_depth
      raise "The 'Bits Allocated' DataElement is missing from this DICOM instance. Unable to encode/decode pixel data." unless exists?("0028,0100")
      return value("0028,0100")
    end

    # Performes a run length decoding on the input stream.
    #
    # === Notes
    #
    # * For details on RLE encoding, refer to the DICOM standard, PS3.5, Section 8.2.2 as well as Annex G.
    #
    # === Parameters
    #
    # * <tt>cols</tt>   - number of colums of the encoded image
    # * <tt>rows</tt>    - number of rows of the encoded image
    # * <tt>string</tt> - packed data
    #
    #--
    # TODO: Remove cols and rows, were only added for debugging.
    #
    def decode_rle(cols, rows, string)
      pixels = Array.new
      # RLE header specifying the number of segments:
      header = string[0...64].unpack('L*')
      image_segments = Array.new
      # Extracting all start and endpoints of the different segments:
      header.each_index do |n|
        if n == 0
          # This one need no processing.
        elsif n == header[0]
          # It's the last one
          image_segments << [header[n], -1]
          break
        else
          image_segments << [header[n], header[n + 1] - 1]
        end
      end
      # Iterate over each segment and extract pixel data:
      image_segments.each do |range|
        segment_data = Array.new
        next_bytes = -1
        next_multiplier = 0
        # Iterate this segment's pixel string:
        string[range[0]..range[1]].each_byte do |b|
          if next_multiplier > 0
            next_multiplier.times { segment_data << b }
            next_multiplier = 0
          elsif next_bytes > 0
            segment_data << b
            next_bytes -= 1
          elsif b <= 127
            next_bytes = b + 1
          else
            # Explaining the 257 at this point is a little bit complicate. Basically it has something
            # to do with the algorithm described in the DICOM standard and that the value -1 as uint8 is 255.
            # TODO: Is this architectur safe or does it only work on Intel systems???
            next_multiplier = 257 - b
          end
        end
        # Verify that the RLE decoding has executed properly:
        throw "Size mismatch #{segment_data.size} != #{rows * cols}" if segment_data.size != rows * cols
        pixels += segment_data
      end
      return pixels
    end

    # Returns the value from the "Photometric Interpretation" DataElement.
    # Raises an error if it is missing.
    #
    def photometry
      raise "The 'Photometric Interpretation' DataElement is missing from this DICOM instance. Unable to encode/decode pixel data." unless exists?("0028,0004")
      return value("0028,0004").upcase
    end

    # Processes the pixel array based on attributes defined in the DICOM object to produce a pixel array
    # with correct pixel colors (RGB) as well as pixel order (RGB-pixel1, RGB-pixel2, etc).
    # The relevant DICOM tags are Photometric Interpretation (0028,0004) and Planar Configuration (0028,0006).
    #
    # === Parameters
    #
    # * <tt>pixels</tt> -- An array of pixel values (integers).
    #
    def process_colors(pixels)
      proper_rgb = false
      photometric = photometry()
      # (With RLE COLOR PALETTE the Planar Configuration is not set)
      planar = self["0028,0006"].is_a?(DataElement) ? self["0028,0006"].value : 0
      # Step 1: Produce an array with RGB values. At this time, YBR is not supported in ruby-dicom,
      # so this leaves us with a possible conversion from PALETTE COLOR:
      if photometric.include?("COLOR")
        # Pseudo colors (rgb values grabbed from a lookup table):
        rgb = Array.new(pixels.length*3)
        # Prepare the lookup data arrays:
        lookup_binaries = [self["0028,1201"].bin, self["0028,1202"].bin, self["0028,1203"].bin]
        lookup_values = Array.new
        nr_bits = self["0028,1101"].value.split("\\").last.to_i
        template = template_string(nr_bits)
        lookup_binaries.each do |bin|
          stream.set_string(bin)
          lookup_values << stream.decode_all(template)
        end
        lookup_values = lookup_values.transpose
        # Fill the RGB array, one RGB pixel group (3 pixels) at a time:
        pixels.each_index do |i|
          rgb[i*3, 3] = lookup_values[pixels[i]]
        end
        # As we have now ordered the pixels in RGB order, modify planar configuration to reflect this:
        planar = 0
      elsif photometric.include?("YBR")
        rgb = false
      else
        rgb = pixels
      end
      # Step 2: If indicated by the planar configuration, the order of the pixels need to be rearranged:
      if rgb
        if planar == 1
          # Rearrange from [RRR...GGG....BBB...] to [(RGB)(RGB)(RGB)...]:
          r_ind = [rgb.length/3-1, rgb.length*2/3-1, rgb.length-1]
          l_ind = [0, rgb.length/3, rgb.length*2/3]
          proper_rgb = [rgb[l_ind[0]..r_ind[0]], rgb[l_ind[1]..r_ind[1]], rgb[l_ind[2]..r_ind[2]]].transpose.flatten
        else
          proper_rgb = rgb
        end
      end
      return proper_rgb
    end

    # Converts original pixel data values to presentation values, which are returned.
    #
    # === Parameters
    #
    # * <tt>pixel_data</tt> -- An array of pixel values (integers).
    # * <tt>min_allowed</tt> -- Fixnum. The minimum value allowed in the returned pixels.
    # * <tt>max_allowed</tt> -- Fixnum. The maximum value allowed in the returned pixels.
    # * <tt>level</tt> -- Boolean or array. If set as true window leveling is performed using default values from the DICOM object. If an array ([center, width]) is specified, these custom values are used instead.
    #
    def process_presentation_values(pixel_data, min_allowed, max_allowed, level=nil)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
      # Have image leveling been requested?
      if level
        # If custom values are specified in an array, use those. If not, the default values from the DICOM object are used:
        if level.is_a?(Array)
          center = level[0]
          width = level[1]
        end
      else
        center, width = false, false
      end
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
    # * <tt>min_allowed</tt> -- Fixnum. The minimum value allowed in the returned pixels.
    # * <tt>max_allowed</tt> -- Fixnum. The maximum value allowed in the returned pixels.
    # * <tt>level</tt> -- Boolean or array. If set as true window leveling is performed using default values from the DICOM object. If an array ([center, width]) is specified, these custom values are used instead.
    #
    def process_presentation_values_narray(pixel_data, min_allowed, max_allowed, level=nil)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
      # Have image leveling been requested?
      if level
        # If custom values are specified in an array, use those. If not, the default values from the DICOM object are used:
        if level.is_a?(Array)
          center = level[0]
          width = level[1]
        end
      else
        center, width = false, false
      end
      # Need to convert to NArray?
      if pixel_data.is_a?(Array)
        n_arr = NArray.to_na(pixel_data)
      else
        n_arr = pixel_data
      end
      # Remap:
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

    # Creates an image object from the specified pixel value array, performing presentation value processing if requested.
    # Returns the image object.
    #
    # === Parameters
    #
    # * <tt>pixel_data</tt> -- An array of pixel values (integers).
    # * <tt>columns</tt> -- Fixnum. Number of columns in the pixel data.
    # * <tt>rows</tt> -- Fixnum. Number of rows in the pixel data.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:remap</tt> -- Boolean. If set, pixel values will be remapped to presentation values (using intercept and slope values from the DICOM object).
    # * <tt>:level</tt> -- Boolean or array. If set (as true) window leveling are performed using default values from the DICOM object. If an array ([center, width]) is specified, these custom values are used instead.
    # * <tt>:narray</tt> -- Boolean. If set as true, forces the use of NArray for the pixel remap process (for faster execution).
    #
    # === Notes
    #
    # * Definitions for Window Center and Width can be found in the DICOM standard, PS 3.3 C.11.2.1.2
    #
    def read_image(pixel_data, columns, rows, options={})
      # Remap the image from pixel values to presentation values if the user has requested this:
      if options[:remap] or options[:level]
        # How to perform the remapping? NArray (fast) or Ruby Array (slow)?
        if options[:narray] == true
          pixel_data = process_presentation_values_narray(pixel_data, 0, 65535, options[:level]).to_a
        else
          pixel_data = process_presentation_values(pixel_data, 0, 65535, options[:level])
        end
      else
        # No remapping, but make sure that we pass on unsigned pixel values to the image processor:
        pixel_data = pixel_data.to_unsigned(bit_depth) if signed_pixels?
      end
      image = import_pixels(pixel_data.to_blob(actual_bit_depth), columns, rows, actual_bit_depth, photometry)
      return image
    end

    # Returns true if the Pixel Representation indicates signed pixel values, and false if it indicates unsigned pixel values.
    # Raises an error if the Pixel Representation element is not present.
    #
    def signed_pixels?
      raise "The 'Pixel Representation' data element is missing from this DICOM instance. Unable to process pixel data." unless exists?("0028,0103")
      case value("0028,0103")
      when 1
        return true
      when 0
        return false
      else
        raise "Invalid value encountered (#{value("0028,0103")}) in the 'Pixel Representation' data element. Expected 0 or 1."
      end
    end

    # Determines and returns a template string for pack/unpacking pixel data, based on
    # the number of bits per pixel as well as the pixel representation (signed or unsigned).
    #
    # === Parameters
    #
    # * <tt>depth</tt> -- Integer. The number of allocated bits in the integers to be decoded/encoded.
    #
    def template_string(depth)
      template = false
      pixel_representation = self["0028,0103"].value.to_i
      # Number of bytes used per pixel will determine how to unpack this:
      case depth
      when 8 # (1 byte)
        template = "BY" # Byte/Character/Fixnum
      when 16 # (2 bytes)
        if pixel_representation == 1
         template = "SS" # Signed short
        else
          template = "US" # Unsigned short
        end
      when 32 # (4 bytes)
        if pixel_representation == 1
          template = "SL" # Signed long
        else
          template = "UL" # Unsigned long
        end
      when 12
        # 12 BIT SIMPLY NOT IMPLEMENTED YET!
        # This one is a bit tricky. I havent really given this priority so far as 12 bit image data is rather rare.
        raise "Packing/unpacking pixel data of bit depth 12 is not implemented yet! Please contact the author (or edit the source code)."
      else
        raise ArgumentError, "Encoding/Decoding pixel data with this Bit Depth (#{depth}) is not implemented."
      end
      return template
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

    # Transfers a pre-encoded binary string to the pixel data element, either by
    # overwriting the existing element value, or creating a new "Pixel Data" element.
    #
    # === Parameters
    #
    # * <tt>bin</tt> -- A binary string containing encoded pixel data.
    #
    def write_pixels(bin)
      if self.exists?(PIXEL_TAG)
        # Update existing Data Element:
        self[PIXEL_TAG].bin = bin
      else
        # Create new Data Element:
        pixel_element = DataElement.new(PIXEL_TAG, bin, :encoded => true, :parent => self)
      end
    end

  end
end
