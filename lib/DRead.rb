#    Copyright 2008-2009 Christoffer Lervåg

# Some notes about this DICOM file reading class:
# In addition to reading files that are compliant to DICOM 3 Part 10, the philosophy of this library
# is to have maximum compatibility, and as such it will read most 'DICOM' files that deviate from the standard.
# While reading files, this class will also analyse the hierarchy of elements for those DICOM files that
# feature sequences and items, enabling the user to take advantage of this information for advanced
# querying of the DICOM object afterwards.

module DICOM
  # Class for reading the data from a DICOM file:
  class DRead

    attr_reader :success,:names,:tags,:types,:lengths,:values,:raw,:levels,:explicit,:file_endian,:msg

    # Initialize the DRead instance.
    def initialize(file_name=nil, opts={})
      # Process option values, setting defaults for the ones that are not specified:
      @lib =  opts[:lib] || DLibrary.new
      @sys_endian = opts[:sys_endian] || false     
      # Initiate the variables that are used during file reading:
      init_variables()
      
      # Test if file is readable and open it to the @file variable:
      open_file(file_name)

      # Read the initial header of the file:
      if @file == nil
        # File is not readable, so we return:
        return
      else
        # Read and verify the DICOM header:
        header = check_header()
        # If the file didnt have the expected header, we will attempt to read data elements from the very start of the file:
        if header == false
          @file.close()
          @file = File.new(file_name, "rb")
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
        data_element = process_data_element()
      end
      
      # Post processing:
      # Close the file as we are finished reading it:
      @file.close()
      # Assume file has been read successfully:
      @success = true
      # Check if the last element was read out correctly (that the length of its data (@raw.last.length)
      # corresponds to that expected by the length specified in the DICOM file (@lengths.last)).
      # We only run this test if the last element has a positive expectation value, obviously.
      if @lengths.last.to_i > 0
        if @raw.last.length != @lengths.last
          @msg += ["Error! The data content read from file does not match the length specified for the tag #{@tags.last}. It seems this is either an invalid or corrupt DICOM file. Returning."]
          @success = false
          return
        end
      end
    end # of method initialize


    # Following methods are private:
    private


    # Checks the initial header of the DICOM file.
    def check_header()
      # According to the official DICOM standard, a DICOM file shall contain 128
      # consequtive (zero) bytes followed by 4 bytes that spell the string 'DICM'.
      # Apparently, some providers seems to skip this in their DICOM files.
      bin1 = @file.read(128)
      @header_length += 128
      # Next 4 bytes should spell 'DICM':
      bin2 = @file.read(4)
      @header_length += 4
      # Check if this binary was successfully read (if not, this short file is not a valid DICOM file and we will return): 
      if bin2
        dicm = bin2.unpack('a' * 4).to_s
      else
        return nil
      end
      if dicm != 'DICM' then
        # Header is not valid (we will still try to read it is a DICOM file though):
        @msg += ["Warning: The specified file does not contain the official DICOM header. Will try to read the file anyway, as some sources are known to skip this header."]
        # As the file is not conforming to the DICOM standard, it is possible that it does not contain a
        # transfer syntax element, and as such, we attempt to choose the most probable encoding values here:
        @explicit = false
        return false
      else
        # Header is valid:
        return true
      end
    end # of method check_header


    # Governs the process of reading data elements from the DICOM file.
    def process_data_element()
      #STEP 1: ------------------------------------------------------
      # Attempt to read data element tag, but abort if we have reached end of file:
      tag = read_tag()
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
      @names += [name]
      @tags += [tag]
      @types += [type]
      @lengths += [length]
      @values += [value]
      @raw += [raw]
      return true
    end # of method process_data_element


    # Reads and returns the data element's TAG (4 first bytes of element).
    def read_tag()
      bin1 = @file.read(2)
      bin2 = @file.read(2)
      # Do not proceed if we have reached end of file:
      if bin2 == nil
        return false
      end
      # Add the length of the data element tag. If this was the first element read from file, we need to add the header length too:
      if @integrated_lengths.length == 0
        # Increase the array with the length of the header + the 4 bytes:
        @integrated_lengths += [@header_length + 4]
      else
        # For the remaining elements, increase the array with the integrated length of the previous elements + the 4 bytes:
        @integrated_lengths += [@integrated_lengths[@integrated_lengths.length-1] + 4]
      end
      # Unpack the blobs:
      tag1 = bin1.unpack('h*').to_s.reverse.upcase
      tag2 = bin2.unpack('h*').to_s.reverse.upcase
      # Whether DICOM file is big or little endian, the first 0002 group is always little endian encoded.
      # In case of big endian system:
      if @sys_endian
        # Rearrange the numbers (# This has never been tested btw.):
        tag1 = tag1[2..3]+tag1[0..1]
        tag2 = tag2[2..3]+tag2[0..1]
      end
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      if tag1 != "0002" and @switched == false
        switch_syntax()
      end
      # Perhaps we need to rearrange the tag strings?
      if not @endian
        # Need to rearrange the first and second part of each string:
        tag1 = tag1[2..3]+tag1[0..1]
        tag2 = tag2[2..3]+tag2[0..1]
      end
      # Join the tag group & element part together to form the final, complete string:
      return tag1+","+tag2
    end # of method read_tag


    # Reads and returns data element TYPE (VR) (2 bytes) and data element LENGTH (Varying length).
    def read_type_length(type,tag)
      # Structure will differ, dependent on whether we have explicit or implicit encoding:
      # *****EXPLICIT*****:
      if @explicit == true
        # Step 1: Read VR (if it exists)
        unless tag == "FFFE,E000" or tag == "FFFE,E00D" or tag == "FFFE,E0DD"
          # Read the element's type (2 bytes - since we are not dealing with an item related element):
          bin = @file.read(2)
          @integrated_lengths[@integrated_lengths.length-1] += 2
          type = bin.unpack('a*').to_s
        end
        # Step 2: Read length
        # Three possible structures for value length here, dependent on element type:
        case type
          when "OB","OW","SQ","UN"
            # 6 bytes total:
            # Two empty first:
            bin = @file.read(2)
            @integrated_lengths[@integrated_lengths.length-1] += 2
            # Value length (4 bytes):
            bin = @file.read(4)
            @integrated_lengths[@integrated_lengths.length-1] += 4
            length = bin.unpack(@ul)[0]
          when "()"
            # 4 bytes:
            # For elements "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD"
            bin = @file.read(4)
            @integrated_lengths[@integrated_lengths.length-1] += 4
            length = bin.unpack(@ul)[0]
          else
            # 2 bytes:
            # For all the other element types, value length is 2 bytes:
            bin = @file.read(2)
            @integrated_lengths[@integrated_lengths.length-1] += 2
            length = bin.unpack(@us)[0]
        end
      else
        # *****IMPLICIT*****:
        # No VR (retrieved from library based on the data element's tag)
        # Reading value length (4 bytes):
        bin = @file.read(4)
        @integrated_lengths[@integrated_lengths.length-1] += 4
        length = bin.unpack(@ul)[0]
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
    end # of method read_type_length


    # Reads and returns data element VALUE (Of varying length - which is determined at an earlier stage).
    def read_value(type, length)
      # Read the data:
      bin = @file.read(length)
      @integrated_lengths[@integrated_lengths.size-1] += length
      # Decoding of content will naturally depend on what kind of content (VR) we have.
      case type

        # Normally the "number elements" will contain just one number, but in some cases, they contain 
        # multiple numbers. In these cases we will read each number and store them all in a string separated by "/".
        # Unsigned long: (4 bytes)
        when "UL"
          if length <= 4
            data = bin.unpack(@ul)[0]
          else
            data = bin.unpack(@ul).join("/")
          end

        # Signed long: (4 bytes)
        when "SL"
          if length <= 4
            data = bin.unpack(@sl)[0]
          else
            data = bin.unpack(@sl).join("/")
          end

        # Unsigned short: (2 bytes)
        when "US"
          if length <= 2
            data = bin.unpack(@us)[0]
          else
            data = bin.unpack(@us).join("/")
          end

        # Signed short: (2 bytes)
        when "SS"
          if length <= 2
            data = bin.unpack(@ss)[0]
          else
            data = bin.unpack(@ss).join("/")
          end

        # Floating point single: (4 bytes)
        when "FL"
          if length <= 4
            data = bin.unpack(@fs)[0]
          else
            data = bin.unpack(@fs).join("/")
          end

        # Floating point double: (8 bytes)
        when "FD"
          if length <= 8
            data = bin.unpack(@fd)[0]
          else
            data = bin.unpack(@fd).join("/")
          end

        # The data element contains a tag as its value (4 bytes):
        when "AT"
          # Bytes read in following order: 1 0 , 3 2 (And Hex nibbles read in this order: Hh)
          # NB! This probably needs to be modified when dealing with something other than little endian.
          # Value is unpacked to a string in the format GGGGEEEE.
          data = (bin.unpack("xHXhX2HXh").join + bin.unpack("x3HXhX2HXh").join).upcase
          #data = (bin.unpack("xHXhX2HXh").join + "," + bin.unpack("x3HXhX2HXh").join).upcase

        # We have a number of VRs that are decoded as string:
        when 'AE','AS','CS','DA','DS','DT','IS','LO','LT','PN','SH','ST','TM','UI','UT' #,'VR'
          data = bin.unpack('a*').to_s
          
        # NB! 
        # FOLLOWING ELEMENT TYPES WILL NOT BE DECODED.
        # DECODING OF PIXEL DATA IS MOVED TO DOBJECT FOR PERFORMANCE REASONS.
        
        # Unknown information, header element is not recognised from local database:
        when "UN"
          #data=bin.unpack('H*')[0]

        # Other byte string, 1-byte integers
        when "OB"
          #data = bin.unpack('H*')[0]
        
        # Other float string, 4-byte floating point numbers
        when "OF"
          # NB! This element type has not been tested yet with an actual DICOM file.
          #data = bin.unpack(@fs)

        # Image data:
        # Other word string, 2-byte integers
        when "OW"
          # empty

        # Unknown VR:
        else
          @msg += ["Warning: Element type #{type} does not have a reading method assigned to it. Please check the validity of the DICOM file."]
          #data = bin.unpack('H*')[0]
      end # of case type
      
      # Return the data:
      return [data, bin]
    end # of method read_value


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
          @hierarchy += [[length,@integrated_lengths.last]]
        else
          @hierarchy += [type]
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
        check_level_end() unless name == "Pixel Data Item" or tag == "FFFE,E0DD"
      end
    end # of method set_level
    
    
    # Checks how far we've read in the DICOM file to determine if we have reached a point
    # where sub-levels are ending. This method is recursive, as multiple sequences/items might end at the same point.
    def check_level_end()
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
            check_level_end()
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
    end # of method check_level_end


    # Tests if the file is readable and opens it.
    def open_file(file)
      if File.exist?(file)
        if File.readable?(file)
          if not File.directory?(file)
            if File.size(file) > 8
              @file = File.new(file, "rb")
            else
              @msg += ["Error! File is too small to contain DICOM information. Returning. (#{file})"]
            end
          else
            @msg += ["Error! File is a directory. Returning. (#{file})"]
          end
        else
          @msg += ["Error! File exists but I don't have permission to read it. Returning. (#{file})"]
        end
      else
        @msg += ["Error! The file you have supplied does not exist. Returning. (#{file})"]
      end
    end # of method open_file


    # Changes encoding variables as the file reading proceeds past the initial 0002 group of the DICOM file.
    def switch_syntax()
      # The information read from the Transfer syntax element (if present), needs to be processed:
      process_transfer_syntax()
      # We only plan to run this method once:
      @switched = true
      # Update endian, explicitness and unpack variables:
      @file_endian = @rest_endian
      @explicit = @rest_explicit
      if @sys_endian == @file_endian
        @endian = true
      else
        @endian = false
      end
      set_unpack_strings()
    end


    # Checks the Transfer Syntax UID element and updates class variables to prepare for correct reading of DICOM file.
    # A lot of code here is duplicated in DWrite class. Should move as much of this code as possible to DLibrary I think.
    def process_transfer_syntax()
      ts_pos = @tags.index("0002,0010")
      if ts_pos != nil
        ts_value = @raw[ts_pos].unpack('a*').to_s.rstrip
        valid = @lib.check_ts_validity(ts_value)
        if not valid
          @msg+=["Warning: Invalid/unknown transfer syntax! Will try reading the file, but errors may occur."]
        end
        case ts_value
          # Some variations with uncompressed pixel data:
          when "1.2.840.10008.1.2"
            # Implicit VR, Little Endian
            @rest_explicit = false
            @rest_endian = false
          when "1.2.840.10008.1.2.1"
            # Explicit VR, Little Endian
            @rest_explicit = true
            @rest_endian = false
          when "1.2.840.10008.1.2.1.99"
            # Deflated Explicit VR, Little Endian
            @msg += ["Warning: Transfer syntax 'Deflated Explicit VR, Little Endian' is untested. Unknown if this is handled correctly!"]
            @rest_explicit = true
            @rest_endian = false
          when "1.2.840.10008.1.2.2"
            # Explicit VR, Big Endian
            @rest_explicit = true
            @rest_endian = true
          else
            # For everything else, assume compressed pixel data, with Explicit VR, Little Endian:
            @rest_explicit = true
            @rest_endian = false
        end # of case ts_value
      end # of if ts_pos != nil
    end # of method process_syntax


    # Sets the unpack format strings that will be used for numbers depending on endianness of file/system.
    def set_unpack_strings
      if @endian
        # System endian equals file endian:
        # Native byte order.
        @by = "C*" # Byte (1 byte)
        @us = "S*" # Unsigned short (2 bytes)
        @ss = "s*" # Signed short (2 bytes)
        @ul = "I*" # Unsigned long (4 bytes)
        @sl = "l*" # Signed long (4 bytes)
        @fs = "e*" # Floating point single (4 bytes)
        @fd = "E*" # Floating point double ( 8 bytes)
      else
        # System endian not equal to file endian:
        # Network byte order.
        @by = "C*"
        @us = "n*"
        @ss = "n*" # Not correct (gives US)
        @ul = "N*"
        @sl = "N*" # Not correct (gives UL)
        @fs = "g*"
        @fd = "G*"
      end
    end


    # Initiates the variables that are used during file reading.
    def init_variables()
      # Variables that hold data that will be available to the DObject class.
      # Arrays that will hold information from the elements of the DICOM file:
      @names = Array.new()
      @tags = Array.new()
      @types = Array.new()
      @lengths = Array.new()
      @values = Array.new()
      @raw = Array.new()
      @levels = Array.new()
      # Array that will holde any messages generated while reading the DICOM file:
      @msg = Array.new()
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
      @integrated_lengths = Array.new()
      @header_length = 0
      # Array to keep track of the hierarchy of elements (this will be used to determine when a sequence or item is finished):
      @hierarchy = Array.new()
      @hierarchy_error = false
      # Explicitness of the remaining groups after the initial 0002 group:
      @rest_explicit = false
      # Endianness of the remaining groups after the first group:
      @rest_endian = false
      # When the file switch from group 0002 to a later group we will update encoding values, and this switch will keep track of that:
      @switched = false
      # Use a "relationship endian" variable to guide reading of file:
      if @sys_endian == @file_endian
        @endian = true
      else
        @endian = false
      end
      # Set which format strings to use when unpacking numbers:
      set_unpack_strings
      # A length variable will be used at the end to check whether the last element was read correctly, or whether the file endend unexpectedly:
      @data_length = 0
      # Keeping track of the data element's level while reading through the file:
      @current_level = 0
      # This variable's string will be inserted as the length of items/sq that dont have a specified length:
      @undef = "UNDEFINED"
      # Items contained under the pixel data element may contain data directly, so we need a variable to keep track of this:
      @enc_image = false
    end

  end # End of class
end # End of module
