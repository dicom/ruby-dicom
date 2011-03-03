#    Copyright 2008-2011 Christoffer Lervag
#
# === Notes
#
# The philosophy of the Ruby DICOM library is to feature maximum conformance to the DICOM standard.
# As such, the class which writes DICOM files may manipulate the meta group, remove/change group lengths and add a header signature.
#
# Therefore, the file that is written may not be an exact bitwise copy of the file that was read,
# even if no DObject manipulation has been done on the part of the user.
#
# Remember: If this behaviour for some reason is not wanted, it is easy to modify the source code to avoid it.
#
# It is important to note, that while the goal is to be fully DICOM compliant, no guarantees are given
# that this is actually achieved. You are encouraged to thouroughly test your files for compatibility after creation.

module DICOM

  # The DWrite class handles the encoding of a DObject instance to a valid DICOM string.
  # The String is either written to file or returned in segments to be used for network transmission.
  #
  class DWrite

    # An array which records any status messages that are generated while encoding/writing the DICOM string.
    attr_reader :msg
    # An array of partial DICOM strings.
    attr_reader :segments
    # A boolean which reports whether the DICOM string was encoded/written successfully (true) or not (false).
    attr_reader :success
    # A boolean which reports the endianness of the post-meta group part of the DICOM string (true for big endian, false for little endian).
    attr_reader :rest_endian
    # A boolean which reports the explicitness of the DICOM string, true if explicit and false if implicit.
    attr_reader :rest_explicit

    # Creates a DWrite instance.
    #
    # === Parameters
    #
    # * <tt>obj</tt> -- A DObject instance which will be used to encode a DICOM string.
    # * <tt>transfer_syntax</tt> -- String. The transfer syntax used for the encoding settings of the post-meta part of the DICOM string.
    # * <tt>file_name</tt> -- A string, either specifying the path of a DICOM file to be loaded, or a binary DICOM string to be parsed.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:signature</tt> -- Boolean. If set as false, the DICOM header signature will not be written to the DICOM file.
    #
    def initialize(obj, transfer_syntax, file_name=nil, options={})
      @obj = obj
      @transfer_syntax = transfer_syntax
      @file_name = file_name
      # As default, signature will be written and meta header added:
      @signature = (options[:signature] == false ? false : true)
      # Array for storing error/warning messages:
      @msg = Array.new
    end

    # Handles the encoding of DICOM information to string as well as writing it to file.
    #
    # === Parameters
    #
    # * <tt>body</tt> -- A DICOM binary string which is duped to file, instead of the normal procedure of encoding element by element.
    #
    #--
    # FIXME: It may seem that the body argument is not used anymore, and should be considered for removal.
    #
    def write(body=nil)
      # Check if we are able to create given file:
      open_file(@file_name)
      # Go ahead and write if the file was opened successfully:
      if @file
        # Initiate necessary variables:
        init_variables
        # Create a Stream instance to handle the encoding of content to a binary string:
        @stream = Stream.new(nil, @file_endian)
        # Tell the Stream instance which file to write to:
        @stream.set_file(@file)
        # Write the DICOM signature:
        write_signature if @signature
        # Write either body or data elements:
        if body
          @stream.add_last(body)
        else
          elements = @obj.children
          write_data_elements(elements)
        end
        # As file has been written successfully, it can be closed.
        @file.close
        # Mark this write session as successful:
        @success = true
      end
    end

    # Writes DICOM content to a series of size-limited binary strings, which is returned in an array.
    # This is typically used in preparation of transmitting DICOM objects through network connections.
    #
    # === Parameters
    #
    # * <tt>max_size</tt> -- Fixnum. The maximum segment string length.
    #
    def encode_segments(max_size)
      # Initiate necessary variables:
      init_variables
      @max_size = max_size
      @segments = Array.new
      elements = @obj.children
      # When sending a DICOM file across the network, no header or meta information is needed.
      # We must therefore find the position of the first tag which is not a meta information tag.
      first_pos = first_non_meta(elements)
      selected_elements = elements[first_pos..-1]
      # Create a Stream instance to handle the encoding of content to
      # the binary string that will eventually be saved to file:
      @stream = Stream.new(nil, @file_endian)
      write_data_elements(selected_elements)
      # Extract the remaining string in our stream instance to our array of strings:
      @segments << @stream.export
      # Mark this write session as successful:
      @success = true
    end


    # Following methods are private:
    private


    # Adds a binary string to (the end of) either the instance file or string.
    #
    def add(string)
      if @file
        @stream.write(string)
      else
        # Are we writing to a single (big) string, or multiple (smaller) strings?
        unless @segments
          @stream.add_last(string)
        else
          # As the encoded DICOM string will be cut in multiple, smaller pieces, we need to monitor the length of our encoded strings:
          if (string.length + @stream.length) > @max_size
            # Duplicate the string as not to ruin the binary of the data element with our slicing:
            segment = string.dup
            append = segment.slice!(0, @max_size-@stream.length)
            # Join these strings together and add them to the segments:
            @segments << @stream.export + append
            if (30 + segment.length) > @max_size
              # The remaining part of the string is bigger than the max limit, fill up more segments:
              # How many full segments will this string fill?
              number = (segment.length/@max_size.to_f).floor
              number.times {@segments << segment.slice!(0, @max_size)}
              # The remaining part is added to the stream:
              @stream.add_last(segment)
            else
              # The rest of the string is small enough that it can be added to the stream:
              @stream.add_last(segment)
            end
          elsif (30 + @stream.length) > @max_size
            # End the current segment, and start on a new segment for this string.
            @segments << @stream.export
            @stream.add_last(string)
          else
            # We are nowhere near the limit, simply add the string:
            @stream.add_last(string)
          end
        end
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

    # Iterates through the data elements, encoding/writing one by one.
    # If an element has children, this is method is repeated recursively.
    #
    # === Notes
    #
    # * Group length data elements are NOT written (they have been deprecated/retired in the DICOM standard).
    #
    # === Parameters
    #
    # * <tt>elements</tt> -- An array of data elements (sorted by their tags).
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
              write_delimiter(element) if element.tag == PIXEL_TAG # (Write a delimiter for the pixel tag, but not for it's items)
            else
              write_delimiter(element)
            end
          else
            # Empty sequence/item or item with binary data (We choose not to write empty, childless parents):
            if element.bin
              write_data_element(element) if element.bin.length > 0
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

    # Encodes and writes a single data element.
    #
    # === Parameters
    #
    # * <tt>element</tt> -- A data element (DataElement, Sequence or Item).
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

    # Encodes and writes an Item or Sequence delimiter.
    #
    # === Parameters
    #
    # * <tt>element</tt> -- A parent element (Item or Sequence).
    #
    def write_delimiter(element)
      delimiter_tag = (element.tag == ITEM_TAG ? ITEM_DELIMITER : SEQUENCE_DELIMITER)
      write_tag(delimiter_tag)
      write_vr_length(delimiter_tag, ITEM_VR, 0)
    end

    # Encodes and writes a tag (the first part of the data element).
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
    #
    def write_tag(tag)
      # Group 0002 is always little endian, but the rest of the file may be little or big endian.
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      switch_syntax if tag.group != META_GROUP and @switched == false
      # Write to binary string:
      bin_tag = @stream.encode_tag(tag)
      add(bin_tag)
    end

    # Encodes and writes the value representation (if it is to be written) and length value.
    # The encoding scheme to be applied here depends on explicitness, data element type and vr.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. The tag of this data element.
    # * <tt>vr</tt> -- String. The value representation of this data element.
    # * <tt>length</tt> -- Fixnum. The data element's length.
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
          add(@stream.encode(vr, "STR"))
        end
        # Step 2: Write length
        # Three possible structures for value length here, dependent on data element vr:
        case vr
          when "OB","OW","OF","SQ","UN","UT"
            if @enc_image # (4 bytes)
              # Item under an encapsulated Pixel Data (7FE0,0010).
              add(length4)
            else # (6 bytes total)
              # Two reserved bytes first:
              add(@stream.encode("00"*2, "HEX"))
              # Value length (4 bytes):
              add(length4)
            end
          when ITEM_VR # (4 bytes)
            # For the item elements: "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD"
            add(length4)
          else # (2 bytes)
            # For all the other data element vr, value length is 2 bytes:
            add(length2)
        end
      else
        # *****IMPLICIT*****:
        # No VR written.
        # Writing value length (4 bytes):
        add(length4)
      end
    end

    # Writes the data element's pre-encoded value.
    #
    # === Parameters
    #
    # * <tt>bin</tt> -- The binary string value of this data element.
    #
    def write_value(bin)
      # This is pretty straightforward, just dump the binary data to the file/string:
      add(bin)
    end


    # Tests if the path/file is writable, creates any folders if necessary, and opens the file for writing.
    #
    # === Parameters
    #
    # * <tt>file</tt> -- A path/file string.
    #
    def open_file(file)
      # Check if file already exists:
      if File.exist?(file)
        # Is it writable?
        if File.writable?(file)
          @file = File.new(file, "wb")
        else
          # Existing file is not writable:
          @msg << "Error! The program does not have permission or resources to create the file you specified: (#{file})"
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
            FileUtils.mkdir_p path
          end
        end
        # The path to this non-existing file is verified, and we can proceed to create the file:
        @file = File.new(file, "wb")
      end
    end

    # Toggles the status for enclosed pixel data.
    #
    # === Parameters
    #
    # * <tt>element</tt> -- A data element (DataElement, Sequence or Item).
    #
    def check_encapsulated_image(element)
      # If DICOM object contains encapsulated pixel data, we need some special handling for its items:
      if element.tag == PIXEL_TAG and element.parent.is_a?(DObject)
        @enc_image = true if element.length <= 0
      end
    end

    # Changes encoding variables as the file writing proceeds past the initial meta group part (0002,xxxx) of the DICOM object.
    #
    def switch_syntax
      # The information from the Transfer syntax element (if present), needs to be processed:
      valid_syntax, @rest_explicit, @rest_endian = LIBRARY.process_transfer_syntax(@transfer_syntax)
      unless valid_syntax
        @msg << "Warning: Invalid/unknown transfer syntax! Will still write the file, but you should give this a closer look."
      end
      # We only plan to run this method once:
      @switched = true
      # Update explicitness and endianness (pack/unpack variables):
      @explicit = @rest_explicit
      @file_endian = @rest_endian
      @stream.endian = @rest_endian
    end

    # Identifies and returns the index of the first data element that does not have a meta group ("0002,xxxx") tag.
    #
    # === Parameters
    #
    # * <tt>elements</tt> -- An array of data elements.
    #
    def first_non_meta(elements)
      non_meta_index = 0
      elements.each_index do |i|
        if elements[i].tag.group != META_GROUP
          non_meta_index = i
          break
        end
      end
      return non_meta_index
    end

    # Creates various variables used when encoding the DICOM string.
    #
    def init_variables
      # Until a DICOM write has completed successfully the status is 'unsuccessful':
      @success = false
      # Default explicitness of start of DICOM file:
      @explicit = true
      # Default endianness of start of DICOM files (little endian):
      @file_endian = false
      # When the file switch from group 0002 to a later group we will update encoding values, and this switch will keep track of that:
      @switched = false
      # Items contained under the Pixel Data element needs some special attention to write correctly:
      @enc_image = false
    end

  end
end