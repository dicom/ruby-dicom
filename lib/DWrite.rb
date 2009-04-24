#    Copyright 2008-2009 Christoffer Lervåg

# Some notes about this DICOM file writing class:
# In its current state, this class will always try to write the file such that it is compliant to the
# official standard (DICOM 3 Part 10), containing header and meta information (group 0002).
# If this is unwanted behaviour, it is easy to modify the source code here to avoid this.
#
# It is important to note, that while the goal is to be fully DICOM compliant, no guarantees are given
# that this is actually achieved. You are encouraged to thouroughly test your files for compatibility after creation. 
# Please contact the author if you discover any issues with file creation.

module DICOM
  # Class for writing the data from DObject to a valid DICOM file:
  class DWrite
    attr_writer :tags, :types, :lengths, :raw, :rest_endian, :rest_explicit
    attr_reader :success, :msg
    
    # Initialize the DWrite instance.
    def initialize(file_name=nil, opts={})
      # Process option values, setting defaults for the ones that are not specified:
      @lib =  opts[:lib] || DLibrary.new
      @sys_endian = opts[:sys_endian] || false
      @file_name = file_name
      
      # Create arrays used for storing data element information:
      @tags = Array.new
      @types = Array.new
      @lengths = Array.new
      @raw = Array.new
      # Array for storing error/warning messages:
      @msg = Array.new
      # Default values that may be overwritten by the user:
      # Explicitness of the remaining groups after the initial 0002 group:
      @rest_explicit = false
      # Endianness of the remaining groups after the first group:
      @rest_endian = false
    end # of method initialize
    
    
    # Writes the DICOM information to file.
    def write()
      if @tags.size > 0
        # Check if we are able to create given file:
        open_file(@file_name)
        # Read the initial header of the file:
        if @file != nil
          # Initiate necessary variables:
          init_variables()
          # Write header:
          write_header()
          # Write meta information (if it is not present in the DICOM object):
          write_meta()
          # Write data elements:
          @tags.each_index do |i|
            write_data_element(i)
          end
          # We are finished writing the data elements, and as such, can close the file:
          @file.close()
          # Mark this write session as successful:
          @success = true
        else
          # File is not writable, so we return:
          # (Error msg already registered in open_file method)
          return
        end # of if @file != nil
      else
        @msg += ["Error. No data elements to write."]
      end # of if @tags.size > 0
    end # of method write
    
    
    # Following methods are private:
    private
    
    
    # Writes the official DICOM header:
    def write_header()
      # Fill in 128 empty bytes:
      @file.write(["00"*128].pack('H*'))
      # Write the string "DICM" which is central to DICOM standards compliance:
      @file.write("DICM")
    end # of write_header
    
    
    # Inserts group 0002 if it is missing, to ensure DICOM compliance.
    def write_meta()
      # We will check for the existance of 5 group 0002 elements, and if they are not present, we will insert them:
      pos = Array.new()
      meta = Array.new()
      # File Meta Information Version:
      pos += [@tags.index("0002,0001")]
      meta += [["0002,0001", "OB", 2, ["0100"].pack("H*")]]
      # Transfer Syntax UID:
      pos += [@tags.index("0002,0010")]
      meta += [["0002,0010", "UI", 18, ["1.2.840.10008.1.2"].pack("a*")+["00"].pack("H*")]] # Implicit, little endian
      # Implementation Class UID:
      pos += [@tags.index("0002,0012")]
      meta += [["0002,0012", "UI", 26, ["1.2.826.0.1.3680043.8.641"].pack("a*")+["00"].pack("H*")]] # Ruby DICOM UID
      # Implementation Version Name:
      pos += [@tags.index("0002,0013")]
      meta += [["0002,0013", "SH", 10, ["RUBY_DICOM"].pack("a*")]]
      # Insert meta information:
      meta_added = false
      pos.each_index do |i|
        # Only insert element if it does not already exist (corresponding pos element shows no match):
        if pos[i] == nil
          meta_added = true
          # Find where to insert this data element.
          index = -1
          tag = meta[i][0]
          quit = false
          while quit != true do
            if tag < @tags[index+1]
              quit = true
            elsif @tags[index+1][0..3] != "0002"
              # Abort to avoid needlessly going through the whole array.
              quit = true
            else
              # Else increase index in anticipation of a 'hit'.
              index += 1
            end
          end # of while
          # Insert data element in the correct array position:
          if index == -1
            # Insert at the beginning of array:
            @tags = [meta[i][0]] + @tags
            @types = [meta[i][1]] + @types
            @lengths = [meta[i][2]] + @lengths
            @raw = [meta[i][3]] + @raw
          else
            # One or more elements comes before this element:
            @tags = @tags[0..index] + [meta[i][0]] + @tags[(index+1)..(@tags.length-1)]
            @types = @types[0..index] + [meta[i][1]] + @types[(index+1)..(@types.length-1)]
            @lengths = @lengths[0..index] + [meta[i][2]] + @lengths[(index+1)..(@lengths.length-1)]
            @raw = @raw[0..index] + [meta[i][3]] + @raw[(index+1)..(@raw.length-1)]
          end # if index == -1
        end # of if pos[i] != nil
      end # of pos.each_index
      # Calculate the length of group 0002:
      length = 0
      quit = false
      j = 0
      while quit == false do
        if @tags[j][0..3] != "0002"
          quit = true
        else
          # Add to length if group 0002:
          if @tags[j] != "0002,0000"
            if @types[j] == "OB"
              length += 12 + @lengths[j]
            else
              length += 8 + @lengths[j]
            end
          end
          j += 1 
        end # of if @tags[j][0..3]..
      end # of while
      # Set group length:
      gl_pos = @tags.index("0002,0000")
      gl_info = ["0002,0000", "UL", 4, [length].pack("I*")]
      # Update group length, but only if there have been some modifications or GL is nonexistant:
      if meta_added == true or gl_pos != nil
        if gl_pos == nil
          # Add group length (to beginning of arrays):
          @tags = [gl_info[0]] + @tags
          @types = [gl_info[1]] + @types
          @lengths = [gl_info[2]] + @lengths
          @raw = [gl_info[3]] + @raw
        else
          # Edit existing group length:
          @tags[gl_pos] = gl_info[0]
          @types[gl_pos] = gl_info[1]
          @lengths[gl_pos] = gl_info[2]
          @raw[gl_pos] = gl_info[3]
        end
      end
    end # of method write_meta
    
    
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
      # Should have some kind of test that the last data was written succesfully?
    end # of method write_data_element
    
    
    # Writes the tag (first part of the data element):
    def write_tag(i)
      # Tag is originally of the form "0002,0010".
      # We need to reformat to get rid of the comma:
      tag = @tags[i][0..3] + @tags[i][5..8]
      # Whether DICOM file is big or little endian, the first 0002 group is always little endian encoded.
      # On a big endian system, I believe the order of the numbers need not be changed,
      # but this has not been tested yet.
      if @sys_endian == false
        # System is little endian:
        # Change the order of the numbers so that it becomes correct when packed as hex:
        tag_corr = tag[2..3] + tag[0..1] + tag[6..7] + tag[4..5]
      end
      # When we shift from group 0002 to another group we need to update our endian/explicitness variables:
      if tag[0..3] != "0002" and @switched == false
        switch_syntax()
      end
      # Perhaps we need to rearrange the tag if the file encoding is now big endian:
      if not @endian
        # Need to rearrange the first and second part of each string:
        tag_corr = tag
      end
      # Write to file:
      @file.write([tag_corr].pack('H*'))
    end # of method write_tag
    
    
    # Writes the type (VR) (if it is to be written) and length value (these two are the middle part of the data element):
    def write_type_length(i)
      # First some preprocessing:
      # Set length value:
      if @lengths[i] == nil
        # Set length value to 0:
        length4 = [0].pack(@ul)
        length2 = [0].pack(@us)
      elsif @lengths[i] == "UNDEFINED"
        # Set length to 'ff ff ff ff':
        length4 = [4294967295].pack(@ul)
        # No length2 necessary for this case.
      else
        # Pick length value from array:
        length4 = [@lengths[i]].pack(@ul)
        length2 = [@lengths[i]].pack(@us)
      end
      # Structure will differ, dependent on whether we have explicit or implicit encoding:
      # *****EXPLICIT*****:
      if @explicit == true
        # Step 1: Write VR (if it is to be written)
        unless @tags[i] == "FFFE,E000" or @tags[i] == "FFFE,E00D" or @tags[i] == "FFFE,E0DD"
          # Write data element type (VR) (2 bytes - since we are not dealing with an item related element):
          @file.write([@types[i]].pack('a*'))
        end
        # Step 2: Write length
        # Three possible structures for value length here, dependent on data element type:
        case @types[i]
          when "OB","OW","SQ","UN"
            if @enc_image
              # Item under an encapsulated Pixel Data (7FE0,0010):
              # 4 bytes:
              @file.write(length4)
            else
              # 6 bytes total:
              # Two empty first:
              @file.write(["00"*2].pack('H*'))
              # Value length (4 bytes):
              @file.write(length4)
            end
          when "()"
            # 4 bytes:
            # For tags "FFFE,E000", "FFFE,E00D" and "FFFE,E0DD"
            @file.write(length4)
          else
            # 2 bytes:
            # For all the other data element types, value length is 2 bytes:
            @file.write(length2)
        end # of case type
      else
        # *****IMPLICIT*****:
        # No VR written.
        # Writing value length (4 bytes):
        @file.write(length4)
      end # of if @explicit == true
    end # of method write_type_length
    
    
    # Writes the value (last part of the data element):
    def write_value(i)
      # This is pretty straightforward, just dump the binary data to the file:
      @file.write(@raw[i])
    end # of method write_value
    
    
    # Tests if the file is writable and opens it.
    def open_file(file)
      # Two cases: File already exists or it does not.
      # Check if file exists:
      if File.exist?(file)
        # Is it writable?
        if File.writable?(file)
          @file = File.new(file, "wb")
        else
          # Existing file is not writable:
          @msg += ["Error! The program does not have permission or resources to create the file you specified. Returning. (#{file})"]
        end
      else
        # File does not exist.
        # Check if this file's path contains a directory that does not exist and so need to be created:
        arr = file.split('/')
        if arr != nil
          # Remove last element (which should be the file string):
          arr.pop
          if arr != nil
            path = arr.join('/')
            # Check if this path exists:
            if not File.directory?(path)
              # Need to create this path:
              require 'fileutils'
              FileUtils.mkdir_p path
            end
          end
        end # of if arr != nil
        # The path to this non-existing file should now be prepared, and we will thus create the file:
        @file = File.new(file, "wb")
      end # of if File.exist?(file)
    end # of method open_file


    # Changes encoding variables as the file writing proceeds past the initial 0002 group of the DICOM file.
    def switch_syntax()
      # The information from the Transfer syntax element (if present), needs to be processed:
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
      set_pack_strings()
    end


    # Checks the Transfer Syntax UID element and updates class variables to prepare for correct writing of DICOM file.
    def process_transfer_syntax()
      ts_pos = @tags.index("0002,0010")
      if ts_pos != nil
        ts_value = @raw[ts_pos].unpack('a*').to_s.rstrip
        valid = @lib.check_ts_validity(ts_value)
        if not valid
          @msg+=["Warning: Invalid/unknown transfer syntax! Will still write the file, but you should give this a closer look."]
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
  
  
    # Sets the pack format strings that will be used for numbers depending on endianness of file/system.
    def set_pack_strings
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
    
    
    # Initializes the variables used when executing this program.
    def init_variables()
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
      # Set which format strings to use when unpacking numbers:
      set_pack_strings
      # Items contained under the Pixel Data element needs some special attention to write correctly:
      @enc_image = false
    end # of method init_variables
  
  end # of class
end # of module