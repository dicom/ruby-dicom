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

  # This class handles the encoding of a DObject to a valid DICOM string and then writing this string to a file.
  class DWrite

    attr_writer :rest_endian, :rest_explicit
    attr_reader :msg, :success, :segments

    # Initializes the DWrite instance.
    def initialize(obj, file_name=nil, options={})
      @obj = obj
      # Process option values, setting defaults for the ones that are not specified:
      @file_name = file_name
      @transfer_syntax = options[:transfer_syntax] || "1.2.840.10008.1.2" # Implicit, little endian
      # Array for storing error/warning messages:
      @msg = Array.new
      # Default values which the user may overwrite afterwards:
      # Explicitness of the remaining groups after the initial 0002 group:
      @rest_explicit = false
      # Endianness of the remaining groups after the first group:
      @rest_endian = false
    end


    # Writes the DICOM information to file.
    def write(body=nil)
      # Check if we are able to create given file:
      open_file(@file_name)
      # Go ahead and write if the file was opened successfully:
      if @file
        # Initiate necessary variables:
        init_variables
        # Create a Stream instance to handle the encoding of content to a binary string:
        @stream = Stream.new(nil, @file_endian, @explicit)
        # Tell the Stream instance which file to write to:
        @stream.set_file(@file)
        # Write the DICOM signature:
        write_signature
        # Write either body or data elements:
        if body
          # Add meta information header:
          write_meta
          @stream.add_last(body)
        else
          elements = @obj.child_array
          # If the DICOM object lacks meta information header, it will be added:
          write_meta unless elements.first.tag[0..3] == "0002"
          write_data_elements(elements)
        end
        # As file has been written successfully, it can be closed.
        @file.close
        # Mark this write session as successful:
        @success = true
      end
    end


    # Write DICOM content to a series of size-limited binary strings
    # (typically used when transmitting DICOM objects through network connections)
    # The method returns an array of binary strings.
    def encode_segments(max_size)
      # Initiate necessary variables:
      init_variables
      @segments = Array.new
      elements = @obj.child_array
      # When sending a DICOM file across the network, no header or meta information is needed.
      # We must therefore find the position of the first tag which is not a meta information tag.
      first_pos = first_non_meta(elements)
      selected_elements = elements[first_pos..-1]
      # Create a Stream instance to handle the encoding of content to
      # the binary string that will eventually be saved to file:
      @stream = Stream.new(nil, @file_endian, @explicit)
      write_data_elements_to_segments(selected_elements, max_size)
      # Mark this write session as successful:
      @success = true
    end


    # Following methods are private:
    private


    # Add a binary string to (the end of) either file or string.
    def add(string)
      if @file
        @stream.write(string)
      else
        @stream.add_last(string)
      end
    end


    # Writes the official DICOM signature header.
    def write_signature
      # Write the string "DICM" which along with the empty bytes that
      # will be put before it, identifies this as a valid DICOM file:
      identifier = @stream.encode("DICM", "STR")
      # Fill in 128 empty bytes:
      filler = @stream.encode("00"*128, "HEX")
      @stream.write(filler)
      @stream.write(identifier)
    end


    # Inserts group 0002 data elements.
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


    # Cycles through the data elements in order to write.
    def write_data_elements(elements)
      elements.each do |element|
        write_data_element(element)
        # If this particular element has children, write these (recursively) before proceeding with elements at the current level:
        write_data_elements(element.child_array) if element.children?
        # We might need to add a Delimiter Item:
        write_delimiter(element) if element.length == -1
      end
    end


    # Writes a single data element.
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
    def write_delimiter(element)
      delimiter_tag = (element.tag == ITEM_TAG ? ITEM_DELIMITER : SEQUENCE_DELIMITER)
      write_tag(delimiter_tag)
      write_vr_length(delimiter_tag, ITEM_VR, -1)
    end


    # Writes each data element to file:
    def write_data_elements_to_segments(elements, max_size)
      # Start encoding data elements, and start on a new string when the size limit is reached:
      elements.each do |element|
        value_length = element.length
        # Test the length of the upcoming data element against our size limitation:
        if value_length > max_size
          # Start writing content from this data element,
          # then continue writing its content in the next segments.
          # Write tag & vr/length:
          write_tag(element.tag)
          write_vr_length(element.tag, element.vr, element.length)
          # Find out how much of this element's value we can write, then add it:
          available = max_size - @stream.length
          value_first_part = element.bin.slice(0, available)
          @stream.add_last(value_first_part)
          # Add segment and reset:
          @segments << @stream.string
          @stream.reset
          # Find out how many more segments our data element value will fill:
          remaining_segments = ((value_length - available).to_f / max_size.to_f).ceil
          index = available
          # Iterate through the data element's value until we have added it entirely:
          remaining_segments.times do
            value = element.bin.slice(index, max_size)
            index = index + max_size
            @stream.add_last(value)
            # Add segment and reset:
            @segments << @stream.string
            @stream.reset
          end
        elsif (20 + value_length + @stream.length) >= max_size
          # End the current segment, and start on a new segment for the next data element.
          @segments << @stream.string
          @stream.reset
          write_data_element(element)
        else
          # Write the next data element to the current segment:
          write_data_element(element)
        end
        check_encapsulated_image(element)
        # If this particular element has children, write these (recursively) before proceeding with elements at the current level:
        write_data_elements_to_segments(element.child_array, max_size) if element.children?
        # We might need to add a Delimiter Item:
        write_delimiter(element) if element.length == -1
      end
    end


    # Writes the tag (first part of the data element).
    def write_tag(tag)
      # Group 0002 is always little endian, but the rest of the file may be little or big endian.
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      switch_syntax if tag[0..3] != "0002" and @switched == false
      # Write to binary string:
      bin_tag = @stream.encode_tag(tag)
      add(bin_tag)
    end


    # Writes the VR (if it is to be written) and length value. These two are the middle part of the data element.
    def write_vr_length(tag, vr, length)
      # First some preprocessing:
      # Set length value:
      if length == nil
        # Set length value to 0:
        length4 = @stream.encode(0, "SL")
        length2 = @stream.encode(0, "US")
      elsif length == -1
        # Set length to 'ff ff ff ff':
        length4 = @stream.encode(-1, "SL")
        # No length2 necessary for this case.
      else
        # Pick length value from array:
        length4 = @stream.encode(length, "SL")
        length2 = @stream.encode(length, "US")
      end
      # Structure will differ, dependent on whether we have explicit or implicit encoding:
      # *****EXPLICIT*****:
      if @explicit == true
        # Step 1: Write VR (if it is to be written)
        unless ITEM_TAGS.include?(tag)
          # Write data element VR (2 bytes - since we are not dealing with an item related element):
          bin_vr = @stream.encode(vr, "STR")
          add(bin_vr)
        end
        # Step 2: Write length
        # Three possible structures for value length here, dependent on data element vr:
        case vr
          when "OB","OW","SQ","UN","UT"
            if @enc_image
              # Item under an encapsulated Pixel Data (7FE0,0010):
              # 4 bytes:
              add(length4)
            else
              # 6 bytes total:
              # Two empty first:
              empty = @stream.encode("00"*2, "HEX")
              add(empty)
              # Value length (4 bytes):
              add(length4)
            end
          when ITEM_VR
            # 4 bytes:
            # For the item elements: "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD"
            add(length4)
          else
            # 2 bytes:
            # For all the other data element vr, value length is 2 bytes:
            add(length2)
        end
      else
        # *****IMPLICIT*****:
        # No VR written.
        # Writing value length (4 bytes):
        add(length4)
      end
    end # of write_vr_length


    # Writes the value (last part of the data element).
    def write_value(bin)
      # This is pretty straightforward, just dump the binary data to the file/string:
      add(bin)
    end


    # Tests if the file/path is writable, creates any folders if necessary, and opens the file for writing.
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


    # Toggle the status for enclosed pixel data.
    def check_encapsulated_image(element)
      # If DICOM object contains encapsulated pixel data, we need some special handling for its items:
      if element.tag == PIXEL_TAG and element.parent.is_a?(DObject)
        @enc_image = true if element.length <= 0
      end
    end


    # Changes encoding variables as the string encoding proceeds past the initial 0002 group of the DICOM object.
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
      @stream.explicit = @rest_explicit
      @stream.set_endian(@rest_endian)
    end


    # Identifies and returns the index of the first element that does not have a group "0002" tag.
    def first_non_meta(elements)
      non_meta_index = 0
      elements.each_index do |i|
        if elements[i].tag[0..3] != "0002"
          non_meta_index = i
          break
        end
      end
      return non_meta_index
    end


    # Initializes the variables used when executing this program.
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