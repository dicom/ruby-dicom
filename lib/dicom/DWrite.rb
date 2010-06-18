#    Copyright 2008-2010 Christoffer Lervag

# Some notes about this DICOM file writing class:
# In its current state, this class will always try to write the file such that it is compliant to the
# official standard (DICOM 3 Part 10), containing header and meta information (group 0002).
# If this is unwanted behaviour, it is easy to modify the source code here to avoid this.
#
# It is important to note, that while the goal is to be fully DICOM compliant, no guarantees are given
# that this is actually achieved. You are encouraged to thouroughly test your files for compatibility after creation.
# Please contact the author if you discover any issues with file creation.

module DICOM

  # The DWrite class handles the encoding of a DObject to a valid DICOM string and writing this string to a file.
  #
  class DWrite

    attr_writer :rest_endian, :rest_explicit
    attr_reader :msg, :success, :segments

    # Initializes a DWrite instance.
    #
    def initialize(obj, file_name=nil, options={})
      @obj = obj
      # Process option values, setting defaults for the ones that are not specified:
      @file_name = file_name
      @transfer_syntax = options[:transfer_syntax] || IMPLICIT_LITTLE_ENDIAN
      # As default, signature will be written and meta header added:
      @signature = (options[:signature] == false ? false : true)
      @add_meta = (options[:add_meta] == false ? false : true)
      # Array for storing error/warning messages:
      @msg = Array.new
      # Default values which the user may overwrite afterwards:
      # Explicitness of the remaining groups after the initial 0002 group:
      @rest_explicit = false
      # Endianness of the remaining groups after the first group:
      @rest_endian = false
    end

    # Writes the DICOM information to file.
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
          # Add meta information header:
          write_meta
          @stream.add_last(body)
        else
          elements = @obj.children
          # If the DICOM object lacks meta information header, it will be added, unless it has been requested that it should not.
          write_meta if @add_meta and elements.first.tag.group != META_GROUP
          write_data_elements(elements)
        end
        # As file has been written successfully, it can be closed.
        @file.close
        # Mark this write session as successful:
        @success = true
      end
    end

    # Writes DICOM content to a series of size-limited binary strings
    # (typically used when transmitting DICOM objects through network connections)
    # The method returns an array of binary strings.
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


    # Adds a binary string to (the end of) either file or string.
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
            append = string.slice!(0, @max_size-@stream.length)
            # Join these strings together and add them to the segments:
            @segments << @stream.export + append
            if (30 + string.length) > @max_size
              # The remaining part of the string is bigger than the max limit, fill up more segments:
              # How many full segments will this string fill?
              number = (string.length/@max_size.to_f).floor
              number.times {@segments << string.slice!(0, @max_size)}
              # The remaining part is added to the stream:
              @stream.add_last(string)
            else
              # The rest of the string is small enough that it can be added to the stream:
              @stream.add_last(string)
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

    # Writes the official DICOM signature header.
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

    # Inserts Meta Group (0002,xxxx) data elements.
    #
    def write_meta
      # File Meta Information Version:
      tag = @stream.encode_tag("0002,0001")
      @stream.add_last(tag)
      @stream.encode_last("OB", "STR")
      @stream.encode_last("0000", "HEX") # (2 reserved bytes)
      @stream.encode_last(2, "UL")
      @stream.encode_last("0001", "HEX") # (Value)
      # Transfer Syntax UID:
      tag = @stream.encode_tag("0002,0010")
      @stream.add_last(tag)
      @stream.encode_last("UI", "STR")
      value = @stream.encode_value(@transfer_syntax, "STR")
      @stream.encode_last(value.length, "US")
      @stream.add_last(value)
      # Implementation Class UID:
      tag = @stream.encode_tag("0002,0012")
      @stream.add_last(tag)
      @stream.encode_last("UI", "STR")
      value = @stream.encode_value(UID, "STR")
      @stream.encode_last(value.length, "US")
      @stream.add_last(value)
      # Implementation Version Name:
      tag = @stream.encode_tag("0002,0013")
      @stream.add_last(tag)
      @stream.encode_last("SH", "STR")
      value = @stream.encode_value(NAME, "STR")
      @stream.encode_last(value.length, "US")
      @stream.add_last(value)
      # Group length:
      # This data element will be put first in the binary string, and built 'backwards'.
      # Value:
      value = @stream.encode(@stream.length, "UL")
      @stream.add_first(value)
      # Length:
      length = @stream.encode(4, "US")
      @stream.add_first(length)
      # VR:
      vr = @stream.encode("UL", "STR")
      @stream.add_first(vr)
      # Tag:
      tag = @stream.encode_tag("0002,0000")
      @stream.add_first(tag)
      # Write the meta information to file:
      @stream.write(@stream.string)
    end

    # Loops through the data elements in order to write.
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
          write_data_element(element) unless element.tag.group_length? # (For simplicity, we avoid writing group length elements)
        end
      end
    end

    # Writes a single data element.
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

    # Writes an item/sequence delimiter for a given item/sequence.
    #
    def write_delimiter(element)
      delimiter_tag = (element.tag == ITEM_TAG ? ITEM_DELIMITER : SEQUENCE_DELIMITER)
      write_tag(delimiter_tag)
      write_vr_length(delimiter_tag, ITEM_VR, 0)
    end

    # Writes the tag (first part of the data element).
    #
    def write_tag(tag)
      # Group 0002 is always little endian, but the rest of the file may be little or big endian.
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      switch_syntax if tag.group != META_GROUP and @switched == false
      # Write to binary string:
      bin_tag = @stream.encode_tag(tag)
      add(bin_tag)
    end

    # Writes the VR (if it is to be written) and length value. These two are the middle part of the data element.
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

    # Writes the value (last part of the data element).
    #
    def write_value(bin)
      # This is pretty straightforward, just dump the binary data to the file/string:
      add(bin)
    end


    # Tests if the file/path is writable, creates any folders if necessary, and opens the file for writing.
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
    def check_encapsulated_image(element)
      # If DICOM object contains encapsulated pixel data, we need some special handling for its items:
      if element.tag == PIXEL_TAG and element.parent.is_a?(DObject)
        @enc_image = true if element.length <= 0
      end
    end

    # Changes encoding variables as the string encoding proceeds past the initial 0002 Meta Group of the DICOM object.
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
      @stream.set_endian(@rest_endian)
    end

    # Identifies and returns the index of the first element that does not have a Meta Group ("0002,xxxx") tag.
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

    # Initializes the variables used when executing this program.
    #
    def init_variables
      # Variables that are accesible from outside:
      # Until a DICOM write has completed successfully the status is 'unsuccessful':
      @success = false
      # Variables used internally:
      # Default explicitness of start of DICOM file:
      @explicit = true
      # Default endianness of start of DICOM files is little endian:
      @file_endian = false
      # When the file switch from group 0002 to a later group we will update encoding values, and this switch will keep track of that:
      @switched = false
      # Items contained under the Pixel Data element needs some special attention to write correctly:
      @enc_image = false
    end

  end # of class
end # of module