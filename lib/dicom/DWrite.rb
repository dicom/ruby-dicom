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

  # Class for writing the data from a DObject to a valid DICOM file.
  class DWrite

    attr_writer :tags, :types, :lengths, :bin, :rest_endian, :rest_explicit
    attr_reader :success, :msg

    # Initialize the DWrite instance.
    def initialize(file_name=nil, options={})
      # Process option values, setting defaults for the ones that are not specified:
      @sys_endian = options[:sys_endian] || false
      @file_name = file_name
      @transfer_syntax = options[:transfer_syntax] || "1.2.840.10008.1.2" # Implicit, little endian

      # Create arrays used for storing data element information:
      @tags = Array.new
      @types = Array.new
      @lengths = Array.new
      @bin = Array.new
      # Array for storing error/warning messages:
      @msg = Array.new
      # Default values that may be overwritten by the user:
      # Explicitness of the remaining groups after the initial 0002 group:
      @rest_explicit = false
      # Endianness of the remaining groups after the first group:
      @rest_endian = false
    end


    # Writes the DICOM information to file.
    def write(body = nil)
      # Check if we are able to create given file:
      open_file(@file_name)
      # Go ahead and write if the file was opened successfully:
      if @file != nil
        # Initiate necessary variables:
        init_variables
        # Create a Stream instance to handle the encoding of content to
        # the binary string that will eventually be saved to file:
        @stream = Stream.new(nil, @file_endian, @explicit)
        # Tell the Stream instance which file to write to:
        @stream.set_file(@file)
        # Write header:
        write_header
        # Meta information:
        # A simple check to determine whether we need to write meta information to the DICOM object:
        if @tags.length > 0
          write_meta unless @tags[0].include?("0002")
        else
          write_meta
        end
        # Write either body or data elements:
        if body
          @stream.add_last(body)
        else
          @tags.each_index do |i|
            write_data_element(i)
          end
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
    def encode_segments(size)
      # Initiate necessary variables:
      init_variables
      # When sending a DICOM file across the network, no header or meta information is needed.
      # We must therefore find the position of the first tag which is not a meta information tag.
      first_pos = first_non_meta
      last_pos = @tags.length - 1
      # Create a Stream instance to handle the encoding of content to
      # the binary string that will eventually be saved to file:
      @stream = Stream.new(nil, @file_endian, @explicit)
      # Start encoding data elements, and start on a new string when the size limit is reached:
      segments = Array.new
      (first_pos..last_pos).each do |i|
        value_length = @lengths[i].to_i
        # Test the length of the upcoming data element against our size limitation:
        if value_length > size
          # Start writing content from this data element,
          # then continue writing its content in the next segments.
          # Write tag & type/length:
          write_tag(i)
          write_type_length(i)
          # Find out how much of this element's value we can write, then add it:
          available = size - @stream.length
          value_first_part = @bin[i].slice(0, available)
          @stream.add_last(value_first_part)
          # Add segment and reset:
          segments << @stream.string
          @stream.reset
          # Find out how many more segments our data element value will fill:
          remaining_segments = ((value_length - available).to_f / size.to_f).ceil
          index = available
          # Iterate through the data element's value until we have added it entirely:
          remaining_segments.times do
            value = @bin[i].slice(index, size)
            index = index + size
            @stream.add_last(value)
            # Add segment and reset:
            segments << @stream.string
            @stream.reset
          end
        elsif (10 + value_length + @stream.length) >= size
          # End the current segment, and start on a new segment for the next data element.
          segments << @stream.string
          @stream.reset
          write_data_element(i)
        else
          # Write the next data element to the current segment:
          write_data_element(i)
        end
      end
      # Mark this write session as successful:
      @success = true
      return segments
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


    # Writes the official DICOM header:
    def write_header
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
      # Type:
      type = @stream.encode("UL", "STR")
      @stream.add_first(type)
      # Tag:
      tag = @stream.encode_tag("0002,0000")
      @stream.add_first(tag)
      # Write the meta information to file:
      @stream.write(@stream.string)
    end


    # Writes each data element to file:
    def write_data_element(i)
      # Step 1: Write tag:
      write_tag(i)
      # Step 2: Write [type] and value length:
      write_type_length(i)
      # Step 3: Write value:
      write_value(i)
      # If DICOM object contains encapsulated pixel data, we need some special handling for its items:
      if @tags[i] == "7FE0,0010"
        @enc_image = true if @lengths[i].to_i == 0
      end
    end


    # Writes the tag (first part of the data element):
    def write_tag(i)
      # Extract current tag:
      tag = @tags[i]
      # Group 0002 is always little endian, but the rest of the file may be little or big endian.
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      if tag[0..3] != "0002" and @switched == false
        switch_syntax
      end
      # Write to binary string:
      bin_tag = @stream.encode_tag(tag)
      add(bin_tag)
    end


    # Writes the type (VR) (if it is to be written) and length value
    # (these two are the middle part of the data element):
    def write_type_length(i)
      # First some preprocessing:
      # Set length value:
      if @lengths[i] == nil
        # Set length value to 0:
        length4 = @stream.encode(0, "UL")
        length2 = @stream.encode(0, "US")
      elsif @lengths[i] == "UNDEFINED"
        # Set length to 'ff ff ff ff':
        length4 = @stream.encode(4294967295, "UL")
        # No length2 necessary for this case.
      else
        # Pick length value from array:
        length4 = @stream.encode(@lengths[i], "UL")
        length2 = @stream.encode(@lengths[i], "US")
      end
      # Structure will differ, dependent on whether we have explicit or implicit encoding:
      # *****EXPLICIT*****:
      if @explicit == true
        # Step 1: Write VR (if it is to be written)
        unless @tags[i] == "FFFE,E000" or @tags[i] == "FFFE,E00D" or @tags[i] == "FFFE,E0DD"
          # Write data element type (VR) (2 bytes - since we are not dealing with an item related element):
          vr = @stream.encode(@types[i], "STR")
          add(vr)
        end
        # Step 2: Write length
        # Three possible structures for value length here, dependent on data element type:
        case @types[i]
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
          when "()"
            # 4 bytes:
            # For tags "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD"
            add(length4)
          else
            # 2 bytes:
            # For all the other data element types, value length is 2 bytes:
            add(length2)
        end # of case type
      else
        # *****IMPLICIT*****:
        # No VR written.
        # Writing value length (4 bytes):
        add(length4)
      end
    end # of write_type_length


    # Writes the value (last part of the data element):
    def write_value(i)
      # This is pretty straightforward, just dump the binary data to the file/string:
      add(@bin[i])
    end


    # Tests if the file/path is writable, creates any folders
    # if necessary, and opens the file for writing.
    def open_file(file)
      # Two cases: File already exists or it does not.
      # Check if file exists:
      if File.exist?(file)
        # Is it writable?
        if File.writable?(file)
          @file = File.new(file, "wb")
        else
          # Existing file is not writable:
          @msg << "Error! The program does not have permission or resources to create the file you specified. Returning. (#{file})"
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
        # The path to this non-existing file should now be prepared, and we proceed to creating the file:
        @file = File.new(file, "wb")
      end
    end


    # Changes encoding variables as the file writing proceeds past the initial 0002 group of the DICOM file.
    def switch_syntax
      # The information from the Transfer syntax element (if present), needs to be processed:
      result = LIBRARY.process_transfer_syntax(@transfer_syntax.rstrip)
      # Result is a 3-element array: [Validity of ts, explicitness, endianness]
      unless result[0]
        @msg << "Warning: Invalid/unknown transfer syntax! Will still write the file, but you should give this a closer look."
      end
      @rest_explicit = result[1]
      @rest_endian = result[2]
      # We only plan to run this method once:
      @switched = true
      # Update explicitness and endianness (pack/unpack variables):
      @file_endian = @rest_endian
      @stream.set_endian(@rest_endian)
      @explicit = @rest_explicit
      @stream.explicit = @rest_explicit
      if @sys_endian == @file_endian
        @endian = true
      else
        @endian = false
      end
    end


    # Find the position of the first tag which is not a group "0002" tag:
    def first_non_meta
      i = 0
      go = true
      while go == true and i < @tags.length do
        tag = @tags[i]
        if tag[0..3] == "0002"
          i += 1
        else
          go = false
        end
      end
      return i
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
      # Use a "relationship endian" variable to guide writing of file:
      if @sys_endian == @file_endian
        @endian = true
      else
        @endian = false
      end
      # Items contained under the Pixel Data element needs some special attention to write correctly:
      @enc_image = false
    end

  end # of class
end # of module