#    Copyright 2008-2009 Christoffer Lervag

# Some notes about this DICOM file reading class:
# In addition to reading files that are compliant to DICOM 3 Part 10, the philosophy of this library
# is to have maximum compatibility, and as such it will read most 'DICOM' files that deviate from the standard.
# While reading files, this class will also analyse the hierarchy of elements for those DICOM files that
# feature sequences and items, enabling the user to take advantage of this information for advanced
# querying of the DICOM object afterwards.

module DICOM
  # Class for reading the data from a DICOM file:
  class DRead

    attr_reader :success, :names, :tags, :types, :lengths, :values, :raw, :levels, :explicit, :file_endian, :msg

    # Initialize the DRead instance.
    def initialize(file_name=nil, options={})
      # Process option values, setting defaults for the ones that are not specified:
      @lib =  options[:lib] || DLibrary.new
      @sys_endian = options[:sys_endian] || false
      # Initiate the variables that are used during file reading:
      init_variables

      # Test if file is readable and open it to the @file variable:
      open_file(file_name)

      # Read the initial header of the file:
      if @file == nil
        # File is not readable, so we return:
        return
      else
        # Extract the content of the file to a binary string:
        @str = @file.read
        @file.close
        # Create a Stream instance to handle the decoding of content from this binary string:
        @stream = Stream.new(@str, @file_endian, @explicit)
        # Read and verify the DICOM header:
        header = check_header
        # If the file didnt have the expected header, we will attempt to read
        # data elements from the very start file:
        if header == false
          @stream.skip(-132)
          @header_length = 0
        elsif header == nil
          # Not a valid DICOM file, return:
          return
        end
      end

      # Run a loop to read the data elements:
      # (Data element information is stored in arrays by the method process_data_element)
      data_element = true
      while data_element != false do
        data_element = process_data_element
      end

      # Post processing:
      # Assume file has been read successfully:
      @success = true
      # Check if the last element was read out correctly (that the length of its data (@raw.last.length)
      # corresponds to that expected by the length specified in the DICOM file (@lengths.last)).
      # We only run this test if the last element has a positive expectation value, obviously.
      if @lengths.last.to_i > 0
        if @raw.last.length != @lengths.last
          @msg << "Error! The data content read from file does not match the length specified for the tag #{@tags.last}. It seems this is either an invalid or corrupt DICOM file. Returning."
          @success = false
          return
        end
      end
    end # of initialize


    # Extract an array of binary strings
    # (this is typically used if one intends to transmit the DICOM file through a network connection)
    def extract_segments(size)
      # For this purpose we are not interested to include header or meta information.
      # We must therefore find the position of the first tag which is not a meta information tag.
      pos = first_non_meta
      # Start position:
      if pos == 0
        start = 0
      else
        # First byte after the integrated length of the previous tag is our start:
        start = @integrated_lengths[pos-1]
      end
      # Iterate through the tags and monitor the integrated_lengths values to determine
      # when we need to start a new segment.
      segments = Array.new
      last_pos = pos
      @tags.each_index do |i|
        # Have we passed the size limit?
        if (@integrated_lengths[i] - start) > size
          # We either need to stop the current segment at the previous tag, or if
          # this is a long tag (typically image data), we need to split its data
          # and put it in several segments.
          if (@integrated_lengths[i] - @integrated_lengths[i-1]) > size
            # This element's value needs to be split up into several segments.
            # How many segments are needed to fit this element?
            number = ((@integrated_lengths[i] - start).to_f / size.to_f).ceil
            number.times do
              # Extract data and add to segments:
              last_pos = (start+size-1)
              segments << @stream.string[start..last_pos]
              # Update start position for next segment:
              start = last_pos + 1
            end
          else
            # End the current segment at the last data element, then start the new segment with this element.
            last_pos = @integrated_lengths[i-1]
            segments << @stream.string[start..last_pos]
            # Update start position for next segment:
            start = last_pos + 1
          end
        end
      end
      # After running the above iteration, it is possible that we have some data elements remaining
      # at the end of the file who's length are beneath the size limit, and thus has not been put into a segment.
      if (last_pos + 1) < @stream.string.length
        # Add the remaining data elements to a segment:
        segments << @stream.string[start..@stream.string.length]
      end
      return segments
    end


    # Following methods are private:
    private


    # Checks the initial header of the DICOM file.
    def check_header
      # According to the official DICOM standard, a DICOM file shall contain 128
      # consequtive (zero) bytes followed by 4 bytes that spell the string 'DICM'.
      # Apparently, some providers seems to skip this in their DICOM files.
      # Check that the file is long enough to contain a valid header:
      if @str.length < 132
        # This does not seem to be a valid DICOM file and so we return.
        return nil
      else
        @stream.skip(128)
        # Next 4 bytes should spell "DICM":
        identifier = @stream.decode(4, "STR")
        @header_length += 132
        if identifier != "DICM" then
          # Header is not valid (we will still try to read it is a DICOM file though):
          @msg << "Warning: The specified file does not contain the official DICOM header. Will try to read the file anyway, as some sources are known to skip this header."
          # As the file is not conforming to the DICOM standard, it is possible that it does not contain a
          # transfer syntax element, and as such, we attempt to choose the most probable encoding values here:
          @explicit = false
          @stream.explicit = false
          return false
        else
          # Header is valid:
          return true
        end
      end
    end


    # Governs the process of reading data elements from the DICOM file.
    def process_data_element
      #STEP 1: ------------------------------------------------------
      # Attempt to read data element tag, but abort if we have reached end of file:
      tag = read_tag
      if tag == false
        # End of file, no more elements.
        return false
      end
      # STEP 2: ------------------------------------------------------
      # Access library to retrieve the data element name and type (VR) from the tag we just read:
      lib_data = @lib.get_name_vr(tag)
      name = lib_data[0]
      vr = lib_data[1]
      # (Note: VR will be overwritten if the DICOM file contains VR)

      # STEP 3: ----------------------------------------------------
      # Read type (VR) (if it exists) and the length value:
      tag_info = read_type_length(vr,tag)
      type = tag_info[0]
      level_type = type
      length = tag_info[1]

      # STEP 4: ----------------------------------------
      # Reading value of data element.
      # Special handling needed for items in encapsulated image data:
      if @enc_image and tag == "FFFE,E000"
        # The first item appearing after the image element is a 'normal' item, the rest hold image data.
        # Note that the first item will contain data if there are multiple images, and so must be read.
        type = "OW" # how about alternatives like OB?
        # Modify name of item if this is an item that holds pixel data:
        if @tags.last != "7FE0,0010"
          name = "Pixel Data Item"
        end
      end
      # Read the value of the element (if it contains data, and it is not a sequence or ordinary item):
      if length.to_i > 0 and type != "SQ" and type != "()"
        # Read the element's value (data):
        data = read_value(type,length)
        value = data[0]
        raw = data[1]
      else
        # Data element has no value (data).
        # Special case: Check if pixel data element is sequenced:
        if tag == "7FE0,0010"
          # Change name and type of pixel data element if it does not contain data itself:
          name = "Encapsulated Pixel Data"
          level_type = "SQ"
          @enc_image = true
        end
      end # of if length.to_i > 0
      # Set the hiearchy level of this data element:
      set_level(level_type, length, tag, name)
      # Transfer the gathered data to arrays and return true:
      @names << name
      @tags << tag
      @types << type
      @lengths << length
      @values << value
      @raw << raw
      return true
    end # of process_data_element


    # Reads and returns the data element's TAG (4 first bytes of element).
    def read_tag
      tag = @stream.decode_tag
      # Do not proceed if we have reached end of file (tag is nil):
      return false unless tag
      # Tag was valid, so we add the length of the data element tag.
      # If this was the first element read from file, we need to add the header length too:
      if @integrated_lengths.length == 0
        # Increase the array with the length of the header + the 4 bytes:
        @integrated_lengths << (@header_length + 4)
      else
        # For the remaining elements, increase the array with the integrated length of the previous elements + the 4 bytes:
        @integrated_lengths << (@integrated_lengths[@integrated_lengths.length-1] + 4)
      end
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      if tag[0..3] != "0002" and @switched == false
        switch_syntax
      end
      return tag
    end


    # Reads and returns data element TYPE (VR) (2 bytes) and data element LENGTH (Varying length; 2-6 bytes).
    def read_type_length(type,tag)
      # Structure will differ, dependent on whether we have explicit or implicit encoding:
      # *****EXPLICIT*****:
      if @explicit == true
        # Step 1: Read VR (if it exists)
        unless tag == "FFFE,E000" or tag == "FFFE,E00D" or tag == "FFFE,E0DD"
          # Read the element's type (2 bytes - since we are not dealing with an item related element):
          type = @stream.decode(2, "STR")
          @integrated_lengths[@integrated_lengths.length-1] += 2
        end
        # Step 2: Read length
        # Three possible structures for value length here, dependent on element type:
        case type
          when "OB","OW","SQ","UN"
            # 6 bytes total:
            # Two empty first:
            @stream.skip(2)
            @integrated_lengths[@integrated_lengths.length-1] += 2
            # Value length (4 bytes):
            length = @stream.decode(4, "UL")
            @integrated_lengths[@integrated_lengths.length-1] += 4
          when "()"
            # 4 bytes:
            # For elements "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD"
            length = @stream.decode(4, "UL")
            @integrated_lengths[@integrated_lengths.length-1] += 4
          else
            # 2 bytes:
            # For all the other element types, value length is 2 bytes:
            length = @stream.decode(2, "US")
            @integrated_lengths[@integrated_lengths.length-1] += 2
        end
      else
        # *****IMPLICIT*****:
        # No VR (retrieved from library based on the data element's tag)
        # Reading value length (4 bytes):
        length = @stream.decode(4, "UL")
        @integrated_lengths[@integrated_lengths.length-1] += 4
      end
      # For encapsulated data, the element length will not be defined. To convey this,
      # the hex sequence 'ff ff ff ff' is used (-1 converted to signed long, 4294967295 converted to unsigned long).
      if length == 4294967295
        length = @undef
      elsif length%2 >0
        # According to the DICOM standard, all data element lengths should be an even number.
        # If it is not, it may indicate a file that is not standards compliant or it might even not be a DICOM file.
        @msg += ["Warning: Odd number of bytes in data element's length occured. This is a violation of the DICOM standard, but program will attempt to read the rest of the file anyway."]
      end
      return [type, length]
    end # of read_type_length


    # Reads and returns data element VALUE (Of varying length - which is determined at an earlier stage).
    def read_value(type, length)
      # Extract the binary data:
      bin = @stream.decode(length, nil, :bin => true)
      @integrated_lengths[@integrated_lengths.size-1] += length
      # Decode data?
      # Some data elements (like those containing image data, compressed data or unknown data),
      # will not be decoded here.
      unless type == "OW" or type == "OB" or type == "OF" or type == "UN"
        # "Rewind" and extract the value from this binary data:
        @stream.skip(-length)
        # Decode data:
        value = @stream.decode(length, type)
        if not value.is_a?(Array)
          data = value
        else
          # If the returned value is not a string, it is an array of multiple elements,
          # which need to be joined to a string with the separator "\":
          data = value.join("\\")
        end
      else
        # No decoded data:
        data = nil
      end
      # Return the data:
      return [data, bin]
    end # of read_value


    # Sets the level of the current element in the hiearchy.
    # The default (top) level is zero.
    def set_level(type, length, tag, name)
      # Set the level of this element:
      @levels += [@current_level]
      # Determine if there is a level change for the following element:
      # If element is a sequence, the level of the following elements will be increased by one.
      # If element is an item, the level of the following elements will likewise be increased by one.
      # Note the following exception:
      # If data element is an "Item", and it contains data (image fragment) directly, which is to say,
      # not in its sub-elements, we should not increase the level. (This is fixed in the process_data_element method.)
      if type == "SQ"
        increase = true
      elsif name == "Item"
        increase = true
      else
        increase = false
      end
      if increase == true
        @current_level = @current_level + 1
        # If length of sequence/item is specified, we must note this length + the current element position in the arrays:
        if length.to_i != 0
          @hierarchy << [length, @integrated_lengths.last]
        else
          @hierarchy << type
        end
      end
      # Need to check whether a previous sequence or item has ended, if so the level must be decreased by one:
      # In the case of tag specification:
      if (tag == "FFFE,E00D") or (tag == "FFFE,E0DD")
        @current_level = @current_level - 1
      end
      # In the case of sequence and item length specification:
      # Check the last position in the hieararchy array.
      # If it is an array (of length and position), then we need to check the integrated_lengths array
      # to see if the current sub-level has expired.
      if @hierarchy.size > 0
        # Do not perform this check for Pixel Data Items or Sequence Delimitation Items:
        # (If performed, it will give false errors for the case when we have Encapsulated Pixel Data)
        check_level_end unless name == "Pixel Data Item" or tag == "FFFE,E0DD"
      end
    end # of set_level


    # Checks how far we've read in the DICOM file to determine if we have reached a point
    # where sub-levels are ending. This method is recursive, as multiple sequences/items might end at the same point.
    def check_level_end
      # The test is only meaningful to perform if we are not expecting an 'end of sequence/item' element to signal the level-change.
      if (@hierarchy.last).is_a?(Array)
        described_length = (@hierarchy.last)[0]
        previous_length = (@hierarchy.last)[1]
        current_length = @integrated_lengths.last
        current_diff = current_length - previous_length
        if current_diff == described_length
          # Decrease level by one:
          @current_level = @current_level - 1
          # Also we need to delete the last entry of the @hierarchy array:
          if (@hierarchy.size > 1)
            @hierarchy = @hierarchy[0..(@hierarchy.size-2)]
            # There might be numerous levels that ends at this particular point, so we need to do a recursive repeat to check.
            check_level_end
          else
            @hierarchy = Array.new()
          end
        elsif current_diff > described_length
          # Only register this type of error one time per file to avoid a spamming effect:
          if not @hierarchy_error
            @msg += ["Unexpected hierarchy incident: Current length difference is greater than the expected value, which should not occur. This will not pose any problems unless you intend to query the object for elements based on hierarchy."]
            @hierarchy_error = true
          end
        end
      end
    end


    # Tests if the file is readable and opens it.
    def open_file(file)
      if File.exist?(file)
        if File.readable?(file)
          if not File.directory?(file)
            if File.size(file) > 8
              @file = File.new(file, "rb")
            else
              @msg << "Error! File is too small to contain DICOM information. Returning. (#{file})"
            end
          else
            @msg << "Error! File is a directory. Returning. (#{file})"
          end
        else
          @msg << "Error! File exists but I don't have permission to read it. Returning. (#{file})"
        end
      else
        @msg << "Error! The file you have supplied does not exist. Returning. (#{file})"
      end
    end


    # Changes encoding variables as the file reading proceeds past the initial 0002 group of the DICOM file.
    def switch_syntax
      # The information from the Transfer syntax element (if present), needs to be processed:
      ts_pos = @tags.index("0002,0010")
      if ts_pos
        transfer_syntax = @values[ts_pos].rstrip
      else
        transfer_syntax = "1.2.840.10008.1.2" # Default is implicit, little endian
      end
      result = @lib.process_transfer_syntax(transfer_syntax)
      # Result is a 3-element array: [Validity of ts, explicitness, endianness]
      unless result[0]
        @msg+=["Warning: Invalid/unknown transfer syntax! Will try reading the file, but errors may occur."]
      end
      @rest_explicit = result[1]
      @rest_endian = result[2]
      # We only plan to run this method once:
      @switched = true
      # Update endian, explicitness and unpack variables:
      @file_endian = @rest_endian
      @stream.set_endian(@rest_endian)
      @explicit = @rest_explicit
      @stream.explicit = @rest_explicit
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


    # Initiates the variables that are used during file reading.
    def init_variables
      # Variables that hold data that will be available to the DObject class.
      # Arrays that will hold information from the elements of the DICOM file:
      @names = Array.new
      @tags = Array.new
      @types = Array.new
      @lengths = Array.new
      @values = Array.new
      @raw = Array.new
      @levels = Array.new
      # Array that will holde any messages generated while reading the DICOM file:
      @msg = Array.new
      # Variables that contain properties of the DICOM file:
      # Variable to keep track of whether the image pixel data in this file are compressed or not, and if it exists at all:
      # Default explicitness of start of DICOM file::
      @explicit = true
      # Default endianness of start of DICOM files is little endian:
      @file_endian = false
      # Variable used to tell whether file was read succesfully or not:
      @success = false

      # Variables used internally when reading through the DICOM file:
      # Array for keeping track of how many bytes have been read from the file up to and including each data element:
      # (This is necessary for tracking the hiearchy in some DICOM files)
      @integrated_lengths = Array.new
      @header_length = 0
      # Array to keep track of the hierarchy of elements (this will be used to determine when a sequence or item is finished):
      @hierarchy = Array.new
      @hierarchy_error = false
      # Explicitness of the remaining groups after the initial 0002 group:
      @rest_explicit = false
      # Endianness of the remaining groups after the first group:
      @rest_endian = false
      # When the file switch from group 0002 to a later group we will update encoding values, and this switch will keep track of that:
      @switched = false
      # A length variable will be used at the end to check whether the last element was read correctly, or whether the file endend unexpectedly:
      @data_length = 0
      # Keeping track of the data element's level while reading through the file:
      @current_level = 0
      # This variable's string will be inserted as the length of items/sq that dont have a specified length:
      @undef = "UNDEFINED"
      # Items contained under the pixel data element may contain data directly, so we need a variable to keep track of this:
      @enc_image = false
    end

  end # of class
end # of module
