module DICOM

  class Parent

    private


    # Adds a binary string to (the end of) either the instance file or string.
    #
    # @param [String] string a pre-encoded string
    #
    def add_encoded(string)
      if @file
        @stream.write(string)
      else
        # Are we writing to a single (big) string, or multiple (smaller) strings?
        unless @segments
          @stream.add_last(string)
        else
          add_with_segmentation(string)
        end
      end
    end

    # Adds an encoded string to the output stream, while keeping track of the
    # accumulated size of the output stream, splitting it up as necessary, and
    # transferring the encoded string fragments to an array.
    #
    # @param [String] string a pre-encoded string
    #
    def add_with_segmentation(string)
      # As the encoded DICOM string will be cut in multiple, smaller pieces, we need to monitor the length of our encoded strings:
      if (string.length + @stream.length) > @max_size
        split_and_add(string)
      elsif (30 + @stream.length) > @max_size
        # End the current segment, and start on a new segment for this string.
        @segments << @stream.export
        @stream.add_last(string)
      else
        # We are nowhere near the limit, simply add the string:
        @stream.add_last(string)
      end
    end

    # Toggles the status for enclosed pixel data.
    #
    # @param [Element, Item, Sequence] element a data element
    #
    def check_encapsulated_image(element)
      # If DICOM object contains encapsulated pixel data, we need some special handling for its items:
      if element.tag == PIXEL_TAG and element.parent.is_a?(DObject)
        @enc_image = true if element.length <= 0
      end
    end

    # Writes DICOM content to a series of size-limited binary strings, which is returned in an array.
    # This is typically used in preparation of transmitting DICOM objects through network connections.
    #
    # @param [Integer] max_size the maximum segment string length
    # @param [Hash] options the options to use for encoding the DICOM strings
    # @option options [String] :syntax the transfer syntax used for the encoding settings of the post-meta part of the DICOM string
    # @return [Array<String>] the encoded DICOM strings
    #
    def encode_in_segments(max_size, options={})
      @max_size = max_size
      @transfer_syntax = options[:syntax]
      # Until a DICOM write has completed successfully the status is 'unsuccessful':
      @write_success = false
      # Default explicitness of start of DICOM file:
      @explicit = true
      # Default endianness of start of DICOM files (little endian):
      @str_endian = false
      # When the file switch from group 0002 to a later group we will update encoding values, and this switch will keep track of that:
      @switched = false
      # Items contained under the Pixel Data element needs some special attention to write correctly:
      @enc_image = false
      # Create a Stream instance to handle the encoding of content to a binary string:
      @stream = Stream.new(nil, @str_endian)
      @segments = Array.new
      write_data_elements(children)
      # Extract the remaining string in our stream instance to our array of strings:
      @segments << @stream.export
      # Mark this write session as successful:
      @write_success = true
      return @segments
    end

    # Tests if the path/file is writable, creates any folders if necessary, and opens the file for writing.
    #
    # @param [String] file a path/file string
    #
    def open_file(file)
      # Check if file already exists:
      if File.exist?(file)
        # Is it writable?
        if File.writable?(file)
          @file = File.new(file, "wb")
        else
          # Existing file is not writable:
          logger.error("The program does not have permission or resources to create this file: #{file}")
        end
      else
        # File does not exist.
        # Check if this file's path contains a folder that does not exist, and therefore needs to be created:
        folders = file.split(File::SEPARATOR)
        if folders.length > 1
          # Remove last element (which should be the file string):
          folders.pop
          path = folders.join(File::SEPARATOR)
          # Check if this path exists:
          unless File.directory?(path)
            # We need to create (parts of) this path:
            require 'fileutils'
            FileUtils.mkdir_p(path)
          end
        end
        # The path to this non-existing file is verified, and we can proceed to create the file:
        @file = File.new(file, "wb")
      end
    end

    # Splits a pre-encoded string in parts and adds it to the segments instance
    # array.
    #
    # @param [String] string a pre-encoded string
    #
    def split_and_add(string)
      # Duplicate the string as not to ruin the binary of the data element with our slicing:
      segment = string.dup
      append = segment.slice!(0, @max_size-@stream.length)
      # Clear out the stream along with a small part of the string:
      @segments << @stream.export + append
      if (30 + segment.length) > @max_size
        # The remaining part of the string is bigger than the max limit, fill up more segments:
        # How many full segments will this string fill?
        number = (segment.length/@max_size.to_f).floor
        start_index = 0
        number.times {
          @segments << segment.slice(start_index, @max_size)
          start_index += @max_size
        }
        # The remaining part is added to the stream:
        @stream.add_last(segment.slice(start_index, segment.length - start_index))
      else
        # The rest of the string is small enough that it can be added to the stream:
        @stream.add_last(segment)
      end
    end

    # Encodes and writes a single data element.
    #
    # @param [Element, Item, Sequence] element a data element
    #
    def write_data_element(element)
      # Step 1: Write tag:
      write_tag(element.tag)
      # Step 2: Write [VR] and value length:
      write_vr_length(element.tag, element.vr, element.length)
      # Step 3: Write value (Insert the already encoded binary string):
      write_value(element.bin)
      check_encapsulated_image(element)
    end

    # Iterates through the data elements, encoding/writing one by one.
    # If an element has children, this method is repeated recursively.
    #
    # @note Group length data elements are NOT written (they are deprecated/retired in the DICOM standard).
    #
    # @param [Array<Element, Item, Sequence>] elements an array of data elements (sorted by their tags)
    #
    def write_data_elements(elements)
      elements.each do |element|
        # If this particular element has children, write these (recursively) before proceeding with elements at the current level:
        if element.is_parent?
          if element.children?
            # Sequence/Item with child elements:
            element.reset_length unless @enc_image
            write_data_element(element)
            write_data_elements(element.children)
            if @enc_image
              # Write a delimiter for the pixel tag, but not for its items:
              write_delimiter(element) if element.tag == PIXEL_TAG
            else
              write_delimiter(element)
            end
          else
            # Parent is childless:
            if element.bin
              write_data_element(element) if element.bin.length > 0
            elsif @include_empty_parents
              # Only write empty/childless parents if specifically indicated:
              write_data_element(element)
              write_delimiter(element)
            end
          end
        else
          # Ordinary Data Element:
          if element.tag.group_length?
            # Among group length elements, only write the meta group element (the others have been retired in the DICOM standard):
            write_data_element(element) if element.tag == "0002,0000"
          else
            write_data_element(element)
          end
        end
      end
    end

    # Encodes and writes an Item or Sequence delimiter.
    #
    # @param [Item, Sequence] element a parent element
    #
    def write_delimiter(element)
      delimiter_tag = (element.tag == ITEM_TAG ? ITEM_DELIMITER : SEQUENCE_DELIMITER)
      write_tag(delimiter_tag)
      write_vr_length(delimiter_tag, ITEM_VR, 0)
    end

    # Handles the encoding of DICOM information to string as well as writing it to file.
    #
    # @param [Hash] options the options to use for encoding the DICOM string
    # @option options [String] :file_name the path & name of the DICOM file which is to be written to disk
    # @option options [Boolean] :signature if true, the 128 byte preamble and 'DICM' signature is prepended to the encoded string
    # @option options [String] :syntax the transfer syntax used for the encoding settings of the post-meta part of the DICOM string
    #
    def write_elements(options={})
      # Check if we are able to create given file:
      open_file(options[:file_name])
      # Go ahead and write if the file was opened successfully:
      if @file
        # Initiate necessary variables:
        @transfer_syntax = options[:syntax]
        # Until a DICOM write has completed successfully the status is 'unsuccessful':
        @write_success = false
        # Default explicitness of start of DICOM file:
        @explicit = true
        # Default endianness of start of DICOM files (little endian):
        @str_endian = false
        # When the file switch from group 0002 to a later group we will update encoding values, and this switch will keep track of that:
        @switched = false
        # Items contained under the Pixel Data element needs some special attention to write correctly:
        @enc_image = false
        # Create a Stream instance to handle the encoding of content to a binary string:
        @stream = Stream.new(nil, @str_endian)
        # Tell the Stream instance which file to write to:
        @stream.set_file(@file)
        # Write the DICOM signature:
        write_signature if options[:signature]
        write_data_elements(children)
        # As file has been written successfully, it can be closed.
        @file.close
        # Mark this write session as successful:
        @write_success = true
      end
    end

    # Writes the DICOM header signature (128 bytes + 'DICM').
    #
    def write_signature
      # Write the string "DICM" which along with the empty bytes that
      # will be put before it, identifies this as a valid DICOM file:
      identifier = @stream.encode("DICM", "STR")
      # Fill in 128 empty bytes:
      filler = @stream.encode("00"*128, "HEX")
      @stream.write(filler)
      @stream.write(identifier)
    end

    # Encodes and writes a tag (the first part of the data element).
    #
    # @param [String] tag a data element tag
    #
    def write_tag(tag)
      # Group 0002 is always little endian, but the rest of the file may be little or big endian.
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      switch_syntax_on_write if tag.group != META_GROUP and @switched == false
      # Write to binary string:
      bin_tag = @stream.encode_tag(tag)
      add_encoded(bin_tag)
    end

    # Writes the data element's pre-encoded value.
    #
    # @param [String] bin the binary string value of this data element
    #
    def write_value(bin)
      # This is pretty straightforward, just dump the binary data to the file/string:
      add_encoded(bin) if bin
    end

    # Encodes and writes the value representation (if it is to be written) and length value.
    # The encoding scheme to be applied here depends on explicitness, data element type and vr.
    #
    # @param [String] tag the tag of this data element
    # @param [String] vr the value representation of this data element
    # @param [Integer] length the data element's length
    #
    def write_vr_length(tag, vr, length)
      # Encode the length value (cover both scenarios of 2 and 4 bytes):
      length4 = @stream.encode(length, "SL")
      length2 = @stream.encode(length, "US")
      # Structure will differ, dependent on whether we have explicit or implicit encoding:
      # *****EXPLICIT*****:
      if @explicit == true
        # Step 1: Write VR (if it is to be written)
        unless ITEM_TAGS.include?(tag)
          # Write data element VR (2 bytes - since we are not dealing with an item related element):
          add_encoded(@stream.encode(vr, "STR"))
        end
        # Step 2: Write length
        # Three possible structures for value length here, dependent on data element vr:
        case vr
          when "OB","OW","OF","SQ","UN","UT"
            if @enc_image # (4 bytes)
              # Item under an encapsulated Pixel Data (7FE0,0010).
              add_encoded(length4)
            else # (6 bytes total)
              # Two reserved bytes first:
              add_encoded(@stream.encode("00"*2, "HEX"))
              # Value length (4 bytes):
              add_encoded(length4)
            end
          when ITEM_VR # (4 bytes)
            # For the item elements: "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD"
            add_encoded(length4)
          else # (2 bytes)
            # For all the other data element vr, value length is 2 bytes:
            add_encoded(length2)
        end
      else
        # *****IMPLICIT*****:
        # No VR written.
        # Writing value length (4 bytes):
        add_encoded(length4)
      end
    end

    # Changes encoding variables as the file writing proceeds past the initial meta
    # group part (0002,xxxx) of the DICOM object.
    #
    def switch_syntax_on_write
      # Process the transfer syntax string to establish encoding settings:
      ts = LIBRARY.uid(@transfer_syntax)
      logger.warn("Invalid/unknown transfer syntax: #{@transfer_syntax} Will complete encoding the file, but an investigation of the result is recommended.") unless ts && ts.transfer_syntax?
      @rest_explicit = ts ? ts.explicit? : true
      @rest_endian = ts ? ts.big_endian? : false
      # Make sure we only run this method once:
      @switched = true
      # Update explicitness and endianness (pack/unpack variables):
      @explicit = @rest_explicit
      @str_endian = @rest_endian
      @stream.endian = @rest_endian
    end

  end

end