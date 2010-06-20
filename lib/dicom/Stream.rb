#    Copyright 2009-2010 Christoffer Lervag

# This file contains the Stream class, which handles all encoding to and
# decoding from binary strings. It is used by the other components of
# Ruby DICOM for tasks such as reading from file, writing to file,
# reading and writing network data packets. These operations have been
# gathered in this one class in an attemt to minimize code duplication.

module DICOM

  # The Stream class handles binary string operations.
  #
  class Stream

    attr_accessor :endian, :index, :string
    attr_reader :errors

    # Initializes a Stream instance.
    #
    def initialize(string, str_endian, options={})
      # Set instance variables:
      @string = string || "" # input binary string
      @index = options[:index] || 0
      @errors = Array.new
      set_endian(str_endian) # true or false
    end

    # Adds a pre-encoded string to the end of this instance's string.
    #
    def add_first(binary)
      @string = binary + @string if binary
    end

    # Adds a pre-encoded string to the beginning of this instance's string.
    #
    def add_last(binary)
      @string = @string + binary if binary
    end

    # Decodes a section of the binary string and returns the formatted data.
    #
    def decode(length, type)
      # Check if values are valid:
      if (@index + length) > @string.length
        # The index number is bigger then the length of the binary string.
        # We have reached the end and will return nil.
        value = nil
      else
        # Decode the binary string and return value:
        value = @string.slice(@index, length).unpack(vr_to_str(type))
        # If the result is an array of one element, return the element instead of the array.
        # If result is contained in a multi-element array, the original array is returned.
        if value.length == 1
          value = value[0]
          # If value is a string, strip away possible trailing whitespace:
          value = value.rstrip if value.is_a?(String)
        end
        # Update our position in the string:
        skip(length)
      end
      return value
    end

    # Decodes the entire binary string and returns the formatted data.
    # Typically used for decoding image data.
    #
    def decode_all(type)
      length = @string.length
      value = @string.slice(@index, length).unpack(vr_to_str(type))
      skip(length)
      return value
    end

    # Decodes a tag from a binary string to our standard ascii format ("GGGG,EEEE").
    #
    def decode_tag
      length = 4
      # Check if values are valid:
      if (@index + length) > @string.length
        # The index number is bigger then the length of the binary string.
        # We have reached the end and will return nil.
        tag = nil
      else
        # Decode and process:
        string = @string.slice(@index, length).unpack(@hex)[0].upcase
        if @endian
          tag = string[2..3] + string[0..1] + "," + string[6..7] + string[4..5]
        else
          tag = string[0..3] + "," + string[4..7]
        end
        # Update our position in the string:
        skip(length)
      end
      return tag
    end

    # Encodes a value (string, number, array of numbers) and returns the resulting binary string.
    #
    def encode(value, type)
      value = [value] unless value.is_a?(Array)
      return value.pack(vr_to_str(type))
    end

    # Encodes content (string, number, array of numbers) to a binary string and pastes it to
    # the beginning of the @string variable of this instance.
    #
    def encode_first(value, type)
      value = [value] unless value.is_a?(Array)
      bin = value.pack(vr_to_str(type))
      @string = bin + @string
    end

    # Encodes content (string, number, array of numbers) to a binary string and pastes it to
    # the end of the @string variable of this instance.
    #
    def encode_last(value, type)
      value = [value] unless value.is_a?(Array)
      bin = value.pack(vr_to_str(type))
      @string = @string + bin
    end

    # Takes a string and pads it with empty spaces to give the string a specified length, encodes it to a binary string and returns it.
    #
    def encode_string_with_trailing_spaces(string, target_length)
      length = string.length
      if length < target_length
        return [string].pack(@str)+["20"*(target_length-length)].pack(@hex)
      elsif length == target_length
        return [string].pack(@str)
      else
        raise "The specified string is longer than the allowed maximum length (String: #{string}, Target length: #{target_length})."
      end
    end

    # Encodes a tag from its standard text format ("GGGG,EEEE"), to a proper binary string.
    #
    def encode_tag(string)
      if @endian
        tag = string[2..3] + string[0..1] + string[7..8] + string[5..6]
      else
        tag = string[0..3] + string[5..8]
      end
      return [tag].pack(@hex)
    end

    # Encodes a value (string, number, array of numbers) and adds an empty byte if the resulting binary string
    # has an odd length. Thus the binary string returned from this method will always have an even length.
    #
    def encode_value(value, type)
      # Make sure the value is in an array:
      value = [value] unless value.is_a?(Array)
      # Get the proper pack string:
      type = vr_to_str(type)
      # Encode:
      bin = value.pack(type)
      # Add an empty byte if the resulting binary has an odd length:
      bin = bin + "\x00" if bin.length[0] == 1
      return bin
    end

    # Extracts and returns the entire binary string, or optionally, just the first part of it if a length is specified as a parameter.
    # The extracted string is removed from the string of this instance.
    #
    def export(length=nil)
      if length
        string = @string.slice!(0, length)
      else
        string = @string
        reset
      end
      return string
    end

    # Extracts and returns a binary string of the given length from the current @index position and out.
    #
    def extract(length)
      str = @string.slice(@index, length)
      skip(length)
      return str
    end

    # Returns the total length of the binary string of this instance.
    #
    def length
      return @string.length
    end

    # Calculates and returns the remaining length of the binary string of this instance.
    #
    def rest_length
      length = @string.length - @index
      return length
    end

    # Extracts and returns the remaining binary string of this instance.
    # (the part of the string which occurs after the position of the @index variable)
    #
    def rest_string
      str = @string[@index..(@string.length-1)]
      return str
    end

    # Resets the string variable (along with the index variable).
    #
    def reset
      @string = ""
      @index = 0
    end

    # Resets the string index variable.
    #
    def reset_index
      @index = 0
    end

    # Updates the endianness to be used for the binary string, and checks
    # the system endianness to determine which encoding/decoding flags to use.
    #
    def set_endian(str_endian)
      # Update endianness variables:
      @str_endian = str_endian
      configure_endian
      set_string_formats
      set_format_hash
    end

    # Set a file variable for the Stream class.
    # For performance reasons, we will enable the Stream class to write directly
    # to file, to avoid expensive string operations which will otherwise slow down write performance.
    #
    def set_file(file)
      @file = file
    end

    # Sets a new binary string for this instance.
    #
    def set_string(binary)
      binary = binary[0] if binary.is_a?(Array)
      @string = binary
      @index = 0
    end

    # Applies an offset (positive or negative) to the index variable.
    #
    def skip(offset)
      @index += offset
    end

    # Writes a binary string to file.
    #
    def write(string)
      @file.write(string)
    end


    # Following methods are private:
    private


    # Determine the endianness of the system.
    # Together with the specified endianness of the binary string, this will decide what encoding/decoding flags to use.
    #
    def configure_endian
      # Use a "relationship endian" variable to guide encoding/decoding options:
      if CPU_ENDIAN == @str_endian
        @endian = true
      else
        @endian = false
      end
    end

    # Converts a data element type (VR) to a encode/decode string used by the pack/unpack methods.
    #
    def vr_to_str(vr)
      unless @format[vr]
        errors << "Warning: Element type #{vr} does not have a reading method assigned to it. Something is not implemented correctly or the DICOM data analyzed is invalid."
        return @hex
      else
        return @format[vr]
      end
    end

    # Sets the hash which is used to convert a data element type (VR) to a encode/decode string.
    #
    def set_format_hash
      @format = {
        "BY" => @by, # Byte/Character (1-byte integers)
        "US" => @us, # Unsigned short (2 bytes)
        "SS" => @ss, # Signed short (2 bytes)
        "UL" => @ul, # Unsigned long (4 bytes)
        "SL" => @sl, # Signed long (4 bytes)
        "FL" => @fs, # Floating point single (4 bytes)
        "FD" => @fd, # Floating point double (8 bytes)
        "OB" => @by, # Other byte string (1-byte integers)
        "OF" => @fs, # Other float string (4-byte floating point numbers)
        "OW" => @us, # Other word string (2-byte integers)
        "AT" => @hex, # Tag reference (4 bytes) NB: This may need to be revisited at some point...
        "UN" => @hex, # Unknown information (header element is not recognized from local database)
        "HEX" => @hex, # HEX
        # We have a number of VRs that are decoded as string:
        "AE" => @str,
        "AS" => @str,
        "CS" => @str,
        "DA" => @str,
        "DS" => @str,
        "DT" => @str,
        "IS" => @str,
        "LO" => @str,
        "LT" => @str,
        "PN" => @str,
        "SH" => @str,
        "ST" => @str,
        "TM" => @str,
        "UI" => @str,
        "UT" => @str,
        "STR" => @str
      }
    end

    # Sets the pack/unpack format strings that will be used for encoding/decoding.
    # Some of these will depend on the endianness of the system and file.
    #
    def set_string_formats
      if @endian
        # System endian equals string endian:
        # Native byte order.
        @us = "S*" # Unsigned short (2 bytes)
        @ss = "s*" # Signed short (2 bytes)
        @ul = "I*" # Unsigned long (4 bytes)
        @sl = "l*" # Signed long (4 bytes)
        @fs = "e*" # Floating point single (4 bytes)
        @fd = "E*" # Floating point double ( 8 bytes)
      else
        # System endian is opposite string endian:
        # Network byte order.
        @us = "n*"
        @ss = "n*" # Not correct (gives US)
        @ul = "N*"
        @sl = "N*" # Not correct (gives UL)
        @fs = "g*"
        @fd = "G*"
      end
      # Format strings that are not dependent on endianness:
      @by = "C*" # Unsigned char (1 byte)
      @str = "a*"
      @hex = "H*" # (this may be dependent on endianness(?))
    end

  end # of class
end # of module