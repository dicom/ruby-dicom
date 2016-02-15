module DICOM

  class Parent

    # Loads data from an encoded DICOM string and creates
    # items and elements which are linked to this instance.
    #
    # @param [String] bin an encoded binary string containing DICOM information
    # @param [String] syntax the transfer syntax to use when decoding the DICOM string
    # @param [Boolean] switched indicating whether the transfer syntax 'switch' has occured in the data stream of this object
    #
    def parse(bin, syntax, switched=false, explicit=true)
      raise ArgumentError, "Invalid argument 'bin'. Expected String, got #{bin.class}." unless bin.is_a?(String)
      raise ArgumentError, "Invalid argument 'syntax'. Expected String, got #{syntax.class}." unless syntax.is_a?(String)
      read(bin, signature=false, :syntax => syntax, :switched => switched, :explicit => explicit)
    end


    private


    # Checks whether the given tag is a duplicate of an existing tag with this parent.
    #
    # @param [String] tag the tag of the candidate duplicate elemental
    # @param [String] elemental the duplicate elemental type (e.g. Sequence, Element)
    #
    def check_duplicate(tag, elemental)
      if @current_parent[tag]
        gp = @current_parent.parent ? "#{@current_parent.parent.representation} => " : ''
        p = @current_parent.representation
        logger.warn("Duplicate #{elemental} (#{tag}) detected at level: #{gp}#{p}")
      end
    end

    # Checks for the official DICOM header signature.
    #
    # @return [Boolean] true if the proper signature is present, false if not, and nil if the string was shorter then the length of the DICOM signature
    #
    def check_header
      # According to the official DICOM standard, a DICOM file shall contain 128 consequtive (zero) bytes,
      # followed by 4 bytes that spell the string 'DICM'. Apparently, some providers seems to skip this in their DICOM files.
      # Check that the string is long enough to contain a valid header:
      if @str.length < 132
        # This does not seem to be a valid DICOM string and so we return.
        return nil
      else
        @stream.skip(128)
        # Next 4 bytes should spell "DICM":
        identifier = @stream.decode(4, "STR")
        @header_length += 132
        if identifier != "DICM" then
          # Header signature is not valid (we will still try to parse it is a DICOM string though):
          logger.warn("This string does not contain the expected DICOM header. Will try to parse the string anyway (assuming a missing header).")
          # As the string is not conforming to the DICOM standard, it is possible that it does not contain a
          # transfer syntax element, and as such, we attempt to choose the most probable encoding values here:
          @explicit = false
          return false
        else
          # Header signature is valid:
          @signature = true
          return true
        end
      end
    end

    # Handles the process of reading a data element from the DICOM string, and
    # creating an element object from the parsed data.
    #
    # @return [Boolean] nil if end of string has been reached (in an expected way), false if the element parse failed, and true if an element was parsed successfully
    #
    def process_data_element
      # FIXME: This method has grown a bit messy and isn't very pleasant to read. Cleanup possible?
      # After having been into a possible unknown sequence with undefined length, we may need to reset
      # explicitness from implicit to explicit:
      if !@original_explicit.nil? && @explicitness_reset_parent == @current_parent
        @explicit = @original_explicit
      end
      # STEP 1:
      # Attempt to read data element tag:
      tag = read_tag
      # Return nil if we have (naturally) reached the end of the data string.
      return nil unless tag
      # STEP 2:
      # Access library to retrieve the data element name and VR from the tag we just read:
      # (Note: VR will be overwritten in the next step if the DICOM string contains VR (explicit encoding))
      name, vr = LIBRARY.name_and_vr(tag)
      # STEP 3:
      # Read VR (if it exists) and the length value:
      vr, length = read_vr_length(vr,tag)
      level_vr = vr
      # STEP 4:
      # Reading value of data element.
      # Special handling needed for items in encapsulated image data:
      if @enc_image and tag == ITEM_TAG
        # The first item appearing after the image element is a 'normal' item, the rest hold image data.
        # Note that the first item will contain data if there are multiple images, and so must be read.
        vr = "OW" # how about alternatives like OB?
        # Modify name of item if this is an item that holds pixel data:
        if @current_element.tag != PIXEL_TAG
          name = PIXEL_ITEM_NAME
        end
      end
      # Read the binary string of the element:
      bin = read_bin(length) if length > 0
      # Read the value of the element (if it contains data, and it is not a sequence or ordinary item):
      if length > 0 and vr != "SQ" and tag != ITEM_TAG
        # Read the element's processed value:
        value = read_value(vr, length)
      else
        # Data element has no value (data).
        value = nil
        # Special case: Check if pixel data element is sequenced:
        if tag == PIXEL_TAG
          # Change name and vr of pixel data element if it does not contain data itself:
          name = ENCAPSULATED_PIXEL_NAME
          level_vr = "SQ"
          @enc_image = true
        end
      end
      # Create an Element from the gathered data:
      # if vr is UN ("unknown") and length is -1, treat as a sequence (sec. 6.2.2 of DICOM standard)
      if level_vr == "SQ" or tag == ITEM_TAG or (level_vr == "UN" and length == -1)
        if level_vr == "SQ" or (level_vr == "UN" and length == -1)
          check_duplicate(tag, 'Sequence')
          # If we get an unknown sequence with undefined length, we must switch to implicit for decoding its content:
          if level_vr == "UN" and length == -1
            @original_explicit = @explicit
            @explicit = false
            @explicitness_reset_parent = @current_parent
          end
          unless @current_parent[tag] and !@overwrite
            @current_element = Sequence.new(tag, :length => length, :name => name, :parent => @current_parent, :vr => vr)
          else
            # We have skipped a sequence. This means that any following children
            # of this sequence must be skipped as well. We solve this by creating an 'orphaned'
            # sequence that has a parent defined, but does not add itself to this parent:
            @current_element = Sequence.new(tag, :length => length, :name => name, :vr => vr)
            @current_element.set_parent(@current_parent)
          end
        elsif tag == ITEM_TAG
          # Create an Item:
          if @enc_image
            @current_element = Item.new(:bin => bin, :length => length, :name => name, :parent => @current_parent, :vr => vr)
          else
            @current_element = Item.new(:length => length, :name => name, :parent => @current_parent, :vr => vr)
          end
        end
        # Common operations on the two types of parent elements:
        if length == 0 and @enc_image
          # Set as parent. Exceptions when parent will not be set:
          # Item/Sequence has zero length & Item is a pixel item (which contains pixels, not child elements).
          @current_parent = @current_element
        elsif length != 0
          @current_parent = @current_element unless name == PIXEL_ITEM_NAME
        end
        # If length is specified (no delimitation items), load a new DRead instance to read these child elements
        # and load them into the current sequence. The exception is when we have a pixel data item.
        if length > 0 and not @enc_image
          @current_element.parse(bin, @transfer_syntax, switched=@switched, @explicit)
          @current_parent = @current_parent.parent
          return false unless @read_success
        end
      elsif DELIMITER_TAGS.include?(tag)
        # We do not create an element for the delimiter items.
        # The occurance of such a tag indicates that a sequence or item has ended, and the parent must be changed:
        @current_parent = @current_parent.parent
      else
        check_duplicate(tag, 'Element')
        unless @current_parent[tag] and !@overwrite
          @current_element = Element.new(tag, value, :bin => bin, :name => name, :parent => @current_parent, :vr => vr)
          # Check that the data stream didn't end abruptly:
          raise "The actual length of the value (#{@current_element.bin.length}) does not match its specified length (#{length}) for Data Element #{@current_element.tag}" if length != @current_element.bin.length
        end
      end
      # Return true to indicate success:
      return true
    end

    # Builds a DICOM object by parsing an encoded DICOM string.
    #
    # @param [String] string a binary DICOM string to be parsed
    # @param [Boolean] signature if true (default), the parsing algorithm will look for the DICOM header signature
    # @param [Hash] options the options to use for parsing the DICOM string
    # @option options [Boolean] :overwrite for the rare case of a DICOM file containing duplicate elements, setting this as true instructs the parsing algorithm to overwrite the original element with duplicates
    # @option options [String] :syntax if a syntax string is specified, the parsing algorithm is forced to use this transfer syntax when decoding the string
    #
    def read(string, signature=true, options={})
      # (Re)Set variables:
      @str = string
      @overwrite = options[:overwrite]
      # Presence of the official DICOM signature:
      @signature = false
      # Default explicitness of start of DICOM string (if undefined it defaults to true):
      @explicit = options[:explicit].nil? ? true : options[:explicit]
      # Default endianness of start of DICOM string is little endian:
      @str_endian = false
      # A switch of endianness may occur after the initial meta group, an this needs to be monitored:
      @switched_endian = false
      # Explicitness of the remaining groups after the initial 0002 group:
      @rest_explicit = false
      # Endianness of the remaining groups after the first group:
      @rest_endian = false
      # When the string switch from group 0002 to a later group we will update encoding values, and this switch will keep track of that:
      @switched = options[:switched] ? options[:switched] : false
      # Keeping track of the data element parent status while parsing the DICOM string:
      @current_parent = self
      # Keeping track of what is the current data element:
      @current_element = self
      # Items contained under the pixel data element may contain data directly, so we need a variable to keep track of this:
      @enc_image = false
      # Assume header size is zero bytes until otherwise is determined:
      @header_length = 0
      # Assume string will be read successfully and toggle it later if we experience otherwise:
      @read_success = true
      # Our encoding instance:
      @stream = Stream.new(@str, @str_endian)
      # If a transfer syntax has been specified as an option for a DICOM object,
      # make sure that it makes it into the object:
      if options[:syntax]
        @transfer_syntax = options[:syntax]
        Element.new("0002,0010", options[:syntax], :parent => self) if self.is_a?(DObject)
      end
      # Check for header information if indicated:
      if signature
        # Read and verify the DICOM header:
        header = check_header
        # If the string is without the expected header, we will attempt
        # to read data elements from the very start of the string:
        if header == false
          @stream.skip(-132)
        elsif header.nil?
          # Not a valid DICOM string, return:
          @read_success = false
          return
        end
      end
      # Run a loop which parses Data Elements, one by one, until the end of the data string is reached:
      data_element = true
      while data_element do
        # Using a rescue clause since processing Data Elements can cause errors when parsing an invalid DICOM string.
        begin
          # Extracting Data element information (nil is returned if end of the string is encountered in a normal way).
          data_element = process_data_element
        rescue Exception => msg
          # The parse algorithm crashed. Set data_element as false to break
          # the loop and toggle the success boolean to indicate failure.
          @read_success = false
          data_element = false
          # Output the raised message as a warning:
          logger.warn(msg.to_s)
          # Ouput the backtrace as debug information:
          logger.debug(msg.backtrace)
          # Explain the failure as an error:
          logger.error("Parsing a Data Element has failed. This is likely caused by an invalid DICOM encoding.")
        end
      end
    end

    # Reads the data element's binary value string (varying length).
    #
    # @param [Integer] length the length of the binary string to be extracted
    # @return [String] the element value
    #
    def read_bin(length)
      return @stream.extract(length)
    end

    # Reads the data element's tag (the 4 first bytes of a data element).
    #
    # @return [String, NilClass] the element tag, or nil (if end of string reached)
    #
    def read_tag
      tag = @stream.decode_tag
      if tag
        # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
        if tag.group != META_GROUP and @switched == false
          switch_syntax_on_read
          # We may need to read our tag again if endian has switched (in which case it has been misread):
          if @switched_endian
            @stream.skip(-4)
            tag = @stream.decode_tag
          end
        end
      end
      return tag
    end

    # Decodes the data element's value (varying length).
    #
    # * Data elements which have multiple numbers as value, will have these numbers joined to a string, separated by the \ character.
    # * For some value representations (OW, OB, OF, UN), a value is not processed, and nil is returned.
    #
    # This means that for data like pixel data, compressed data, unknown data, a value is not
    # available in the data element, and must be processed from the data element's binary variable.
    #
    # @param [String] vr the value representation of the data element which the value to be decoded belongs to
    # @param [Integer] length the length of the binary string to be extracted
    # @return [String, NilClass] the data element value
    #
    def read_value(vr, length)
      unless vr == "OW" or vr == "OB" or vr == "OF" or vr == "UN"
        # Since the binary string has already been extracted for this data element, we must first "rewind":
        @stream.skip(-length)
        # Decode data:
        value = @stream.decode(length, vr)
        # If the returned value is an array of multiple values, we will join these values to a string with the separator "\":
        value = value.join("\\") if value.is_a?(Array)
      else
        # No decoded value:
        value = nil
      end
      return value
    end

    # Reads the data element's value representation (2 bytes), as well as the
    # data element's length (varying length: 2-6 bytes). The decoding scheme
    # to be applied depends on explicitness, data element type and vr.
    #
    # @param [String] vr the value representation that was retrieved from the dictionary for the tag of this data element
    # @param [String] tag the tag of this data element
    # @return [Array<String, Integer>] the value representation and length of the element
    #
    def read_vr_length(vr, tag)
      # Structure will differ, dependent on whether we have explicit or implicit encoding:
      reserved = 0
      bytes = 0
      # *****EXPLICIT*****:
      if @explicit == true
        # Step 1: Read VR, 2 bytes (if it exists - which are all cases except for the item related elements)
        vr = @stream.decode(2, "STR") unless ITEM_TAGS.include?(tag)
        # Step 2: Read length
        # Three possible structures for value length here, dependent on element vr:
        case vr
          when "OB","OW","OF","SQ","UN","UT"
            # 6 bytes total (2 reserved bytes preceeding the 4 byte value length)
            reserved = 2
            bytes = 4
          when ITEM_VR
            # For the item elements: "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD":
            bytes = 4
          else
            # For all the other element vr, value length is 2 bytes:
            bytes = 2
        end
      else
        # *****IMPLICIT*****:
        bytes = 4
      end
      # Handle skips and read out length value:
      @stream.skip(reserved)
      if bytes == 2
        length = @stream.decode(bytes, "US") # (2)
      else
        length = @stream.decode(bytes, "SL") # (4)
      end
      # Check that length is valid (according to the DICOM standard, it must be even):
      raise "Encountered a Data Element (#{tag}) with an invalid (odd) value length." if length.odd? and length > 0
      return vr, length
    end

    # Changes encoding variables as the parsing proceeds past the initial meta
    # group part (0002,xxxx) of the DICOM string.
    #
    def switch_syntax_on_read
      # Get the transfer syntax string, unless it has already been provided by keyword:
      @transfer_syntax = (self["0002,0010"] ? self["0002,0010"].value : IMPLICIT_LITTLE_ENDIAN) unless @transfer_syntax
      # Query the library with our particular transfer syntax string:
      ts = LIBRARY.uid(@transfer_syntax)
      logger.warn("Invalid/unknown transfer syntax: #{@transfer_syntax} Will try parsing the string, but errors may occur.") unless ts && ts.transfer_syntax?
      @rest_explicit = ts ? ts.explicit? : true
      @rest_endian = ts ? ts.big_endian? : false
      # Make sure we only run this method once:
      @switched = true
      # Update endian, explicitness and unpack variables:
      @switched_endian = true if @rest_endian != @str_endian
      @str_endian = @rest_endian
      @stream.endian = @rest_endian
      @explicit = @rest_explicit
    end

  end

end
