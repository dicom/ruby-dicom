#    Copyright 2009 Christoffer Lervag

# This file contains the Stream class, which handles all encoding to and
# decoding from binary strings. It is used by the other components of
# Ruby DICOM for tasks such as reading from file, writing to file,
# reading and writing network data packets. These operations have been
# gathered in this one class in an attemt to minimize code duplication.

module DICOM
  # Class for handling string operations:
  class Stream

    attr_accessor :endian, :explicit, :index
    attr_reader :errors

    def initialize(string, str_endian, explicit, options={})
      # Set instance variables:
      @explicit = explicit # true or false
      @string = string # input binary string, or nil if empty
      @index = options[:index] || 0
      set_endian(str_endian) # true or false
    end

    # Determine the endianness of the system.
    # Together with the specified endianness of the binary string,
    # this will decide what encoding/decoding flags to use.
    def configure_endian
      x = 0xdeadbeef
      endian_type = {
        Array(x).pack("V*") => false, #:little
        Array(x).pack("N*") => true   #:big
      }
      @sys_endian = endian_type[Array(x).pack("L*")]
      # Use a "relationship endian" variable to guide encoding/decoding options:
      if @sys_endian == @str_endian
        @endian = true
      else
        @endian = false
      end
    end

    # Decodes a section of the binary string and returns the formatted data.
    def decode(length, type, options = {})
      # Check if values are valid:
      if (@index + length) > @string.length
        # The index number is bigger then the length of the binary string
        # we have reached the end and will return nil.
        value = nil
      else
        # Decode the string, unless the binary string itself is wanted:
        if options[:bin] == true
          # Return binary string:
          value = @string.slice(@index, length)
        else
          # Decode the binary string and return value:
          value = @string.slice(@index, length).unpack(vr_to_str(type))
          # If the result is an array of one element, return the element instead of the array.
          # If result is contained in a multi-element array, return the original array.
          value = value[0] if value.length == 1
        end
        # Update our position in the string:
        skip(length)
      end
      return value
    end

    # This method updates the endianness to be used for the binary string, and checks
    # the system endianness to determine which encoding/decoding flags to use.
    def set_endian(str_endian)
      # Update endianness variables:
      @str_endian = str_endian
      configure_endian
      set_string_formats
      set_format_hash
    end

    # Set the hash which is used to convert a data element type (VR) to a encode/decode string.
    def set_format_hash
      @format = {
        "UL" => @ul, # Unsigned long (4 bytes)
        "SL" => @sl, # Signed long (4 bytes)
        "US" => @us, # Unsigned short (2 bytes)
        "SS" => @ss, # Signed short (2 bytes)
        "FL" => @fl, # Floating point single (4 bytes)
        "FD" => @fd, # Floating point double (8 bytes)
        "OB" => @by, # Other byte string (1-byte integers)
        "OF" => @fl, # Other float string (4-byte floating point numbers)
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
    def set_string_formats
      if @endian
        # System endian equals string endian:
        # Native byte order.
        @by = "C*" # Byte (1 byte)
        @us = "S*" # Unsigned short (2 bytes)
        @ss = "s*" # Signed short (2 bytes)
        @ul = "I*" # Unsigned long (4 bytes)
        @sl = "l*" # Signed long (4 bytes)
        @fs = "e*" # Floating point single (4 bytes)
        @fd = "E*" # Floating point double ( 8 bytes)
      else
        # System endian is opposite string endian:
        # Network byte order.
        @by = "C*"
        @us = "n*"
        @ss = "n*" # Not correct (gives US)
        @ul = "N*"
        @sl = "N*" # Not correct (gives UL)
        @fs = "g*"
        @fd = "G*"
      end
      # Format strings that are not dependent on endianness:
      @str = "a*"
      @hex = "H*" # (this may be dependent on endianness, not tested yet..)
    end

    # Applies an offset (positive or negative) to the index variable.
    def skip(offset)
      @index += offset
    end

    # Convert a data element type (VR) to a encode/decode string.
    def vr_to_str(vr)
      str = @format[vr]
      if str == nil
        errors << "Warning: Element type #{vr} does not have a reading method assigned to it. Something is not implemented correctly or the DICOM data analyzed is invalid."
        str = @hex
      end
      return str
    end

  end
end