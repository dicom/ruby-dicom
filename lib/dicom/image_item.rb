module DICOM

  # Super class which contains common code for both the DObject and Item classes.
  # This class includes the image related methods, since images may be stored either
  # directly in the DObject, or in items (encapsulated items in the "Pixel Data"
  # element or in "Icon Image Sequence" items).
  #
  # === Inheritance
  #
  # As the ImageItem class inherits from the Parent class, all Parent methods are
  # also available to objects which has inherited ImageItem.
  #
  class ImageItem < Parent

    include ImageProcessor

    # Creates an Element with the given arguments and connects it to self.
    #
    # @param [String] tag an element tag
    # @param [String, Integer, Float, Array, NilClass] value an element value
    # @param [Hash] options any options used for creating the element (see Element.new documentation)
    #
    def add_element(tag, value, options={})
      add(e = Element.new(tag, value, options))
      e
    end

    # Creates a Sequence with the given arguments and connects it to self.
    #
    # @param [String] tag a sequence tag
    # @param [Hash] options any options used for creating the sequence (see Sequence.new documentation)
    #
    def add_sequence(tag, options={})
      add(s = Sequence.new(tag, options))
      s
    end

    # Checks if colored pixel data is present.
    #
    # @return [Boolean] true if the object contains colored pixels, and false if not
    #
    def color?
      # "Photometric Interpretation" is contained in the data element "0028,0004":
      begin
        photometric = photometry
        if photometric.include?('COLOR') or photometric.include?('RGB') or photometric.include?('YBR')
          return true
        else
          return false
        end
      rescue
        return false
      end
    end

    # Checks if compressed pixel data is present.
    #
    # @return [Boolean] true if the object contains compressed pixels, and false if not
    #
    def compression?
      # If compression is used, the pixel data element is a Sequence (with encapsulated elements), instead of a Element:
      if self[PIXEL_TAG].is_a?(Sequence)
        return true
      else
        return false
      end
    end

    # Unpacks pixel values from a binary pixel string. The decode is performed
    # using values defined in the image related elements of the DObject instance.
    #
    # @param [String] bin a binary string containing the pixels to be decoded
    # @param [Stream] stream a Stream instance to be used for decoding the pixels (optional)
    # @return [Array<Integer>] decoded pixel values
    #
    def decode_pixels(bin, stream=@stream)
      raise ArgumentError, "Expected String, got #{bin.class}." unless bin.is_a?(String)
      pixels = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth_element = self['0028,0100']
      pixel_representation_element = self['0028,0103']
      if bit_depth_element and pixel_representation_element
        # Load the binary pixel data to the Stream instance:
        stream.set_string(bin)
        template = template_string(bit_depth_element.value.to_i)
        pixels = stream.decode_all(template) if template
      else
        raise "The Element specifying Bit Depth (0028,0100) is missing. Unable to decode pixel data." unless bit_depth_element
        raise "The Element specifying Pixel Representation (0028,0103) is missing. Unable to decode pixel data." unless pixel_representation_element
      end
      return pixels
    end

    # Packs a pixel value array to a binary pixel string. The encoding is performed
    # using values defined in the image related elements of the DObject instance.
    #
    # @param [Array<Integer>] pixels an array containing the pixel values to be encoded
    # @param [Stream] stream a Stream instance to be used for encoding the pixels (optional)
    # @return [String] encoded pixel string
    #
    def encode_pixels(pixels, stream=@stream)
      raise ArgumentError, "Expected Array, got #{pixels.class}." unless pixels.is_a?(Array)
      bin = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth_element = self['0028,0100']
      pixel_representation_element = self['0028,0103']
      if bit_depth_element and pixel_representation_element
        template = template_string(bit_depth_element.value.to_i)
        bin = stream.encode(pixels, template) if template
      else
        raise "The Element specifying Bit Depth (0028,0100) is missing. Unable to encode the pixel data." unless bit_depth_element
        raise "The Element specifying Pixel Representation (0028,0103) is missing. Unable to encode the pixel data." unless pixel_representation_element
      end
      return bin
    end

    # Extracts a single image object, created from the encoded pixel data using
    # the image related elements in the DICOM object. If the object contains multiple
    # image frames, the first image frame is returned, unless the :frame option is used.
    #
    # @note Creates an image object in accordance with the selected image processor. Available processors are :rmagick and :mini_magick.
    #
    # @param [Hash] options the options to use for extracting the image
    # @option options [Integer] :frame for DICOM objects containing multiple frames, this option can be used to extract a specific image frame (defaults to 0)
    # @option options [TrueClass, Array<Integer>] :level if true, window leveling is performed using default values from the DICOM object, or if an array ([center, width]) is specified, these custom values are used instead
    # @option options [Boolean] :narray if true, forces the use of NArray for the pixel remap process (for faster execution)
    # @option options [Boolean] :remap if true, the returned pixel values are remapped to presentation values
    # @return [MagickImage, NilClass, FalseClass] an image object, alternatively nil (if no image present) or false (if image decode failed)
    #
    # @example Retrieve pixel data as an RMagick image object and display it
    #   image = dcm.image
    #   image.display
    # @example Retrieve frame index 5 in the pixel data
    #   image = dcm.image(:frame => 5)
    #
    def image(options={})
      options[:frame] = options[:frame] || 0
      image = images(options).first
      image = false if image.nil? && exists?(PIXEL_TAG)
      return image
    end

    # Extracts an array of image objects, created from the encoded pixel data using
    # the image related elements in the DICOM object.
    #
    # @note Creates an array of image objects in accordance with the selected image processor. Available processors are :rmagick and :mini_magick.
    #
    # @param [Hash] options the options to use for extracting the images
    # @option options [Integer] :frame makes the method return an array containing only the image object corresponding to the specified frame number
    # @option options [TrueClass, Array<Integer>] :level if true, window leveling is performed using default values from the DICOM object, or if an array ([center, width]) is specified, these custom values are used instead
    # @option options [Boolean] :narray if true, forces the use of NArray for the pixel remap process (for faster execution)
    # @option options [Boolean] :remap if true, the returned pixel values are remapped to presentation values
    # @return [Array<MagickImage, NilClass>] an array of image objects, alternatively an empty array (if no image present or image decode failed)
    #
    # @example Retrieve the pixel data as RMagick image objects
    #   images = dcm.images
    # @example Retrieve the pixel data as RMagick image objects, remapped to presentation values (but without any leveling)
    #   images = dcm.images(:remap => true)
    # @example Retrieve the pixel data as RMagick image objects, remapped to presentation values and leveled using the default center/width values in the DICOM object
    #   images = dcm.images(:level => true)
    # @example Retrieve the pixel data as RMagick image objects, remapped to presentation values, leveled with the specified center/width values and using numerical array for the rescaling (~twice as fast)
    #   images = dcm.images(:level => [-200,1000], :narray => true)
    #
    def images(options={})
      images = Array.new
      if exists?(PIXEL_TAG)
        # Gather the pixel data strings, and pick a single frame if indicated by options:
        strings = image_strings(split_to_frames=true)
        strings = [strings[options[:frame]]] if options[:frame]
        if compression?
          # Decompress, either to numbers (RLE) or to an image object (image based compressions):
          if [TXS_RLE].include?(transfer_syntax)
            pixel_frames = Array.new
            strings.each {|string| pixel_frames << decode_rle(num_cols, num_rows, string)}
          else
            images = decompress(strings) || Array.new
            logger.warn("Decompressing pixel values has failed (unsupported transfer syntax: '#{transfer_syntax}' - #{LIBRARY.uid(transfer_syntax) ? LIBRARY.uid(transfer_syntax).name : 'Unknown transfer syntax!'})") unless images.length > 0
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
              images << read_image(pixels, num_cols, num_rows, options)
            else
              logger.warn("Processing pixel values for this particular color mode failed, unable to construct image(s).")
            end
          end
        end
      end
      return images
    end

    # Reads a binary string from a specified file and writes it to the value field of the pixel data element (7FE0,0010).
    #
    # @param [String] file a string which specifies the path of the file containing pixel data
    #
    # @example Load pixel data from a file
    #   dcm.image_from_file("custom_image.dat")
    #
    def image_from_file(file)
      raise ArgumentError, "Expected #{String}, got #{file.class}." unless file.is_a?(String)
      f = File.new(file, 'rb')
      bin = f.read(f.stat.size)
      if bin.length > 0
        # Write the binary data to the Pixel Data Element:
        write_pixels(bin)
      else
        logger.info("The specified file (#{file}) is empty. Nothing to transfer.")
      end
    end

    # Extracts the pixel data binary string(s) in an array.
    #
    # @param [Boolean] split if true, a pixel data string containing 3D volumetric data will be split into N substrings (where N equals the number of frames)
    # @return [Array<String, NilClass>] an array of pixel data strings, or an empty array (if no pixel data present)
    #
    def image_strings(split=false)
      # Pixel data may be a single binary string in the pixel data element,
      # or located in several encapsulated item elements:
      pixel_element = self[PIXEL_TAG]
      strings = Array.new
      if pixel_element.is_a?(Element)
        if split
          strings = pixel_element.bin.dup.divide(num_frames)
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
    # If the DICOM object contains multi-fragment pixel data, each fragment
    # will be dumped to separate files (e.q. 'fragment-0.dat', 'fragment-1.dat').
    #
    # @param [String] file a string which specifies the file path to use when dumping the pixel data
    # @example Dumping the pixel data to a file
    #   dcm.image_to_file("exported_image.dat")
    #
    def image_to_file(file)
      raise ArgumentError, "Expected #{String}, got #{file.class}." unless file.is_a?(String)
      # Split the file name in case of multiple fragments:
      parts = file.split('.')
      if parts.length > 1
        base = parts[0..-2].join
        extension = '.' + parts.last
      else
        base = file
        extension = ''
      end
      # Get the binary image strings and dump them to the file(s):
      images = image_strings
      images.each_index do |i|
        if images.length == 1
          f = File.new(file, 'wb')
        else
          f = File.new("#{base}-#{i}#{extension}", 'wb')
        end
        f.write(images[i])
        f.close
      end
    end

    # Encodes pixel data from a (Magick) image object and writes it to the
    # pixel data element (7FE0,0010).
    #
    # Because of pixel value issues related to image objects (images don't like
    # signed integers), and the possible difference between presentation values
    # and raw pixel values, the use of image=() may result in pixel data where the
    # integer values differs somewhat from what is expected. Use with care! For
    # precise pixel value processing, use the Array and NArray based pixel data methods instead.
    #
    # @param [MagickImage] image the image to be assigned to the pixel data element
    #
    def image=(image)
      raise ArgumentError, "Expected one of the supported image classes: #{valid_image_objects} (got #{image.class})" unless valid_image_objects.include?(image.class.to_s)
      # Export to pixels using the proper image processor:
      pixels = export_pixels(image, photometry)
      # Encode and write to the Pixel Data Element:
      self.pixels = pixels
    end

    # Gives the number of columns in the pixel data.
    #
    # @return [Integer, NilClass] the number of columns, or nil (if the columns value is undefined)
    #
    def num_cols
      self['0028,0011'].value rescue nil
    end

    # Gives the number of frames in the pixel data.
    #
    # @note Assumes and gives 1 if the number of frames value is not defined.
    # @return [Integer] the number of rows
    #
    def num_frames
      (self['0028,0008'].is_a?(Element) == true ? self['0028,0008'].value.to_i : 1)
    end

    # Gives the number of rows in the pixel data.
    #
    # @return [Integer, NilClass] the number of rows, or nil (if the rows value is undefined)
    #
    def num_rows
      self['0028,0010'].value rescue nil
    end

    # Creates an NArray containing the pixel data. If the pixel data is an image
    # (single frame), a 2-dimensional NArray is returned [columns, rows]. If the
    # pixel data is 3-dimensional (more than one frame), a 3-dimensional NArray
    # is returned [frames, columns, rows].
    #
    # @note To call this method you need to have loaded the NArray library in advance (require 'narray').
    #
    # @param [Hash] options the options to use for extracting the pixel data
    # @option options [TrueClass, Array<Integer>] :level if true, window leveling is performed using default values from the DICOM object, or if an array ([center, width]) is specified, these custom values are used instead
    # @option options [Boolean] :remap if true, the returned pixel values are remapped to presentation values
    # @option options [Boolean] :volume if true, the returned array will always be 3-dimensional, even if the pixel data only has one frame
    # @return [NArray, NilClass, FalseClass] an NArray of pixel values, alternatively nil (if no image present) or false (if image decode failed)
    #
    # @example Retrieve numerical pixel array
    #   data = dcm.narray
    # @example Retrieve numerical pixel array remapped from the original pixel values to presentation values
    #   data = dcm.narray(:remap => true)
    #
    def narray(options={})
      pixels = nil
      if exists?(PIXEL_TAG)
        unless color?
          # Decode the pixel values: For now we only support returning pixel data of the first frame (if the image is located in multiple pixel data items).
          if compression?
            pixels = decompress(image_strings.first)
          else
            pixels = decode_pixels(image_strings.first)
          end
          if pixels
            # Import the pixels to NArray and give it a proper shape:
            raise "Missing Rows and/or Columns Element. Unable to construct pixel data array." unless num_rows and num_cols
            if num_frames > 1 or options[:volume]
              # Create an empty 3D NArray. fill it with pixels frame by frame, then reassign the pixels variable to it:
              narr = NArray.int(num_frames, num_cols, num_rows)
              num_frames.times do |i|
                narr[i, true, true] = NArray.to_na(pixels[(i * num_cols * num_rows)..((i + 1) * num_cols * num_rows - 1)]).reshape!(num_cols, num_rows)
              end
              pixels = narr
            else
              pixels = NArray.to_na(pixels).reshape!(num_cols, num_rows)
            end
            # Remap the image from pixel values to presentation values if the user has requested this:
            pixels = process_presentation_values_narray(pixels, -65535, 65535, options[:level]) if options[:remap] or options[:level]
          else
            logger.warn("Decompressing the Pixel Data failed. Pixel values can not be extracted.")
          end
        else
          logger.warn("The DICOM object contains colored pixel data. Retrieval of colored pixels is not supported by this method yet.")
          pixels = false
        end
      end
      return pixels
    end

    # Extracts the Pixel Data values in an ordinary Ruby Array.
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    #
    # The returned array does not carry the dimensions of the pixel data:
    # It is put in a one dimensional Array (vector).
    #
    # @param [Hash] options the options to use for extracting the pixel data
    # @option options [TrueClass, Array<Integer>] :level if true, window leveling is performed using default values from the DICOM object, or if an array ([center, width]) is specified, these custom values are used instead
    # @option options [Boolean] :narray if true, forces the use of NArray for the pixel remap process (for faster execution)
    # @option options [Boolean] :remap if true, the returned pixel values are remapped to presentation values
    # @return [Array, NilClass, FalseClass] an Array of pixel values, alternatively nil (if no image present) or false (if image decode failed)
    #
    # @example Simply retrieve the pixel data
    #   pixels = dcm.pixels
    # @example Retrieve the pixel data remapped to presentation values according to window center/width settings
    #   pixels = dcm.pixels(:remap => true)
    # @example Retrieve the remapped pixel data while using numerical array (~twice as fast)
    #   pixels = dcm.pixels(:remap => true, :narray => true)
    #
    def pixels(options={})
      pixels = nil
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
          logger.warn("Decompressing the Pixel Data failed. Pixel values can not be extracted.")
        end
      end
      return pixels
    end

    # Encodes pixel data from a Ruby Array or NArray, and writes it to the pixel data element (7FE0,0010).
    #
    # @param [Array<Integer>, NArray] values an Array (or NArray) containing integer pixel values
    #
    def pixels=(values)
      raise ArgumentError, "The given argument does not respond to #to_a (got an argument of class #{values.class})" unless values.respond_to?(:to_a)
      if values.class.ancestors.to_s.include?('NArray')
        # With an NArray argument, make sure that it gets properly converted to an Array:
        if values.shape.length > 2
          # For a 3D NArray we need to rearrange to ensure that the pixels get their
          # proper order when converting to an ordinary Array instance:
          narr = NArray.int(values.shape[1] * values.shape[2], values.shape[0])
          values.shape[0].times do |i|
            narr[true, i] = values[i, true, true].reshape(values.shape[1] * values.shape[2])
          end
          values = narr
        end
      end
      # Encode the pixel data:
      bin = encode_pixels(values.to_a.flatten)
      # Write the binary data to the Pixel Data Element:
      write_pixels(bin)
    end

    # Delete all Sequence instances from the DObject or Item instance.
    #
    def delete_sequences
      @tags.each_value do |element|
        delete(element.tag) if element.is_a?(Sequence)
      end
    end


    private


    # Gives the effective bit depth of the pixel data (considers a special case
    # for Palette colored images).
    #
    # @raise [RuntimeError] if the 'Bits Allocated' element is missing
    # @return [Integer] the effective bit depth of the pixel data
    #
    def actual_bit_depth
      raise "The 'Bits Allocated' Element is missing from this DICOM instance. Unable to encode/decode pixel data." unless exists?("0028,0100")
      if photometry == PI_PALETTE_COLOR
      # Only one channel is checked and it is assumed that all channels have the same number of bits.
        return self['0028,1101'].value.split("\\").last.to_i
      else
        return bit_depth
      end
    end


    # Gives the value from the "Bits Allocated" Element.
    #
    # @raise [RuntimeError] if the 'Bits Allocated' element is missing
    # @return [Integer] the number of bits allocated
    #
    def bit_depth
      raise "The 'Bits Allocated' Element is missing from this DICOM instance. Unable to encode/decode pixel data." unless exists?("0028,0100")
      return value('0028,0100')
    end

    # Performs a run length decoding on the input stream.
    #
    # @note For details on RLE encoding, refer to the DICOM standard, PS3.5, Section 8.2.2 as well as Annex G.
    #
    # @param [Integer] cols number of colums of the encoded image
    # @param [Integer] rows number of rows of the encoded image
    # @param [Integer] string the encoded pixel string
    # @return [Array<Integer>] the decoded pixel values
    #
    def decode_rle(cols, rows, string)
      # FIXME: Remove cols and rows (were only added for debugging).
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

    # Gives the value from the "Photometric Interpretation" Element.
    #
    # @raise [RuntimeError] if the 'Photometric Interpretation' element is missing
    # @return [String] the photometric interpretation
    #
    def photometry
      raise "The 'Photometric Interpretation' Element is missing from this DICOM instance. Unable to encode/decode pixel data." unless exists?("0028,0004")
      return value('0028,0004').upcase
    end

    # Processes the pixel array based on attributes defined in the DICOM object,
    #to produce a pixel array with correct pixel colors (RGB) as well as pixel
    # order (RGB-pixel1, RGB-pixel2, etc). The relevant DICOM tags are
    # Photometric Interpretation (0028,0004) and Planar Configuration (0028,0006).
    #
    # @param [Array<Integer>] pixels an array of (unsorted) color pixel values
    # @return [Array<Integer>] an array of properly (sorted) color pixel values
    #
    def process_colors(pixels)
      proper_rgb = false
      photometric = photometry()
      # (With RLE COLOR PALETTE the Planar Configuration is not set)
      planar = self['0028,0006'].is_a?(Element) ? self['0028,0006'].value : 0
      # Step 1: Produce an array with RGB values. At this time, YBR is not supported in ruby-dicom,
      # so this leaves us with a possible conversion from PALETTE COLOR:
      if photometric.include?('COLOR')
        # Pseudo colors (rgb values grabbed from a lookup table):
        rgb = Array.new(pixels.length*3)
        # Prepare the lookup data arrays:
        lookup_binaries = [self['0028,1201'].bin, self['0028,1202'].bin, self['0028,1203'].bin]
        lookup_values = Array.new
        nr_bits = self['0028,1101'].value.split("\\").last.to_i
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
      elsif photometric.include?('YBR')
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

    # Converts original pixel data values to presentation values.
    #
    # @param [Array<Integer>] pixel_data an array of pixel values (integers)
    # @param [Integer] min_allowed the minimum value allowed in the pixel data
    # @param [Integer] max_allowed the maximum value allowed in the pixel data
    # @param [Boolean, Array<Integer>] level if true, window leveling is performed using default values from the DICOM object, or if an array ([center, width]) is specified, these custom values are used instead
    # @return [Array<Integer>] presentation values
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
    # @note If a Ruby Array is supplied, the method returns a one-dimensional NArray object (i.e. no columns & rows).
    # @note If a NArray is supplied, the NArray is returned with its original dimensions.
    #
    # @param [Array<Integer>, NArray] pixel_data pixel values
    # @param [Integer] min_allowed the minimum value allowed in the pixel data
    # @param [Integer] max_allowed the maximum value allowed in the pixel data
    # @param [Boolean, Array<Integer>] level if true, window leveling is performed using default values from the DICOM object, or if an array ([center, width]) is specified, these custom values are used instead
    # @return [Array<Integer>, NArray] presentation values
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

    # Creates an image object from the specified pixel value array, performing
    # presentation value processing if requested.
    #
    # @note Definitions for Window Center and Width can be found in the DICOM standard, PS 3.3 C.11.2.1.2
    #
    # @param [Array<Integer>] pixel_data an array of pixel values
    # @param [Integer] columns the number of columns in the pixel data
    # @param [Integer] rows the number of rows in the pixel data
    # @param [Hash] options the options to use for reading the image
    # @option options [Boolean] :remap if true, pixel values are remapped to presentation values (using intercept and slope values from the DICOM object)
    # @option options [Boolean, Array<Integer>] :level if true, window leveling is performed using default values from the DICOM object, or if an array ([center, width]) is specified, these custom values are used instead
    # @option options [Boolean] :narray if true, forces the use of NArray for the pixel remap process (for faster execution)
    # @return [MagickImage] the extracted image object
    #
    def read_image(pixel_data, columns, rows, options={})
      raise ArgumentError, "Expected Array for pixel_data, got #{pixel_data.class}" unless pixel_data.is_a?(Array)
      raise ArgumentError, "Expected Integer for columns, got #{columns.class}" unless columns.is_a?(Integer)
      raise ArgumentError, "Expected Rows for columns, got #{rows.class}" unless rows.is_a?(Integer)
      raise ArgumentError, "Size of pixel_data must be at least equal to columns*rows. Got #{columns}*#{rows}=#{columns*rows}, which is less than the array size #{pixel_data.length}" if columns * rows > pixel_data.length
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

    # Checks if the Pixel Representation indicates signed pixel values or not.
    #
    # @raise [RuntimeError] if the 'Pixel Representation' element is missing
    # @return [Boolean] true if pixel values are signed, false if not
    #
    def signed_pixels?
      raise "The 'Pixel Representation' data element is missing from this DICOM instance. Unable to process pixel data." unless exists?("0028,0103")
      case value('0028,0103')
      when 1
        return true
      when 0
        return false
      else
        raise "Invalid value encountered (#{value('0028,0103')}) in the 'Pixel Representation' data element. Expected 0 or 1."
      end
    end

    # Determines the template/format string for pack/unpacking pixel data, based on
    # the number of bits per pixel as well as the pixel representation (signed or unsigned).
    #
    # @param [Integer] depth the number of allocated bits in the integers to be decoded/encoded
    # @return [String] a format string
    #
    def template_string(depth)
      template = false
      pixel_representation = self['0028,0103'].value.to_i
      # Number of bytes used per pixel will determine how to unpack this:
      case depth
      when 8 # (1 byte)
        template = 'BY' # Byte/Character/Fixnum
      when 16 # (2 bytes)
        if pixel_representation == 1
         template = 'SS' # Signed short
        else
          template = 'US' # Unsigned short
        end
      when 32 # (4 bytes)
        if pixel_representation == 1
          template = 'SL' # Signed long
        else
          template = 'UL' # Unsigned long
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

    # Collects the window level values needed to convert the original pixel
    # values to presentation values.
    #
    # @note If some of these values are missing in the DObject instance,
    #   default values are used instead for intercept and slope, while center
    #   and width are set to nil. No errors are raised.
    # @return [Array<Integer, NilClass>] center, width, intercept and slope
    #
    def window_level_values
      center = (self['0028,1050'].is_a?(Element) == true ? self['0028,1050'].value.to_i : nil)
      width = (self['0028,1051'].is_a?(Element) == true ? self['0028,1051'].value.to_i : nil)
      intercept = (self['0028,1052'].is_a?(Element) == true ? self['0028,1052'].value.to_i : 0)
      slope = (self['0028,1053'].is_a?(Element) == true ? self['0028,1053'].value.to_i : 1)
      return center, width, intercept, slope
    end

    # Transfers a pre-encoded binary string to the pixel data element, either by
    # overwriting the existing element value, or creating a new "Pixel Data" element.
    #
    # @param [String] bin a binary string containing encoded pixel data
    #
    def write_pixels(bin)
      if self.exists?(PIXEL_TAG)
        # Update existing Data Element:
        self[PIXEL_TAG].bin = bin
      else
        # Create new Data Element:
        pixel_element = Element.new(PIXEL_TAG, bin, :encoded => true, :parent => self)
      end
    end

  end
end