module DICOM

  # The Stream class handles string operations (encoding to and decoding from binary strings).
  # It is used by the various classes of ruby-dicom for tasks such as reading and writing
  # from/to files or network packets.
  #
  # @note In practice, this class is for internal library use. It is typically not accessed
  #   by the user, and can thus be considered a 'private' class.
  #
  class Stream

    # A boolean which reports the relationship between the endianness of the system and the instance string.
    attr_reader :equal_endian
    # Our current position in the instance string (used only for decoding).
    attr_accessor :index
    # The instance string.
    attr_accessor :string
    # The endianness of the instance string.
    attr_reader :str_endian
    # An array of warning/error messages that (may) have been accumulated.
    attr_reader :errors
    # A hash with vr as key and its corresponding pad byte as value.
    attr_reader :pad_byte

    # Creates a Stream instance.
    #
    # @param [String, NilClass] binary a binary string (or nil, if creating an empty instance)
    # @param [Boolean] string_endian the endianness of the instance string (true for big endian, false for small endian)
    # @param [Hash] options the options to use for creating the instance
    # @option options [Integer] :index a position (offset) in the instance string where reading will start
    #
    def initialize(binary, string_endian, options={})
      @string = binary || ''
      @index = options[:index] || 0
      @errors = Array.new
      self.endian = string_endian
    end

    # Prepends a pre-encoded string to the instance string (inserts at the beginning).
    #
    # @param [String] binary a binary string
    #
    def add_first(binary)
      @string = "#{binary}#{@string}" if binary
    end

    # Appends a pre-encoded string to the instance string (inserts at the end).
    #
    # @param [String] binary a binary string
    #
    def add_last(binary)
      @string = "#{@string}#{binary}" if binary
    end

    # Decodes a section of the instance string.
    # The instance index is offset in accordance with the length read.
    #
    # @note If multiple numbers are decoded, these are returned in an array.
    # @param [Integer] length the string length to be decoded
    # @param [String] type the type (vr) of data to decode
    # @return [String, Integer, Float, Array] the formatted (decoded) data
    #
    def decode(length, type)
      raise ArgumentError, "Invalid argument length. Expected Fixnum, got #{length.class}" unless length.is_a?(Fixnum)
      raise ArgumentError, "Invalid argument type. Expected string, got #{type.class}" unless type.is_a?(String)
      value = nil
      if (@index + length) <= @string.length
        # There are sufficient bytes remaining to extract the value:
        if type == 'AT'
          # We need to guard ourselves against the case where a string contains an invalid 'AT' value:
          if length == 4
            value = decode_tag
          else
            # Invalid. Just return nil.
            skip(length)
          end
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
      end
      value
    end

    # Decodes the entire instance string (typically used for decoding image data).
    #
    # @note If multiple numbers are decoded, these are returned in an array.
    # @param [String] type the type (vr) of data to decode
    # @return [String, Integer, Float, Array] the formatted (decoded) data
    #
    def decode_all(type)
      length = @string.length
      value = @string.slice(@index, length).unpack(vr_to_str(type))
      skip(length)
      return value
    end

    # Decodes 4 bytes of the instance string and formats it as a ruby-dicom tag string.
    #
    # @return [String, NilClass] a formatted tag string ('GGGG,EEEE'), or nil (e.g. if at end of string)
    #
    def decode_tag
      length = 4
      tag = nil
      if (@index + length) <= @string.length
        # There are sufficient bytes remaining to extract a full tag:
        str = @string.slice(@index, length).unpack(@hex)[0].upcase
        if @equal_endian
          tag = "#{str[2..3]}#{str[0..1]},#{str[6..7]}#{str[4..5]}"
        else
          tag = "#{str[0..3]},#{str[4..7]}"
        end
        # Update our position in the string:
        skip(length)
      end
      tag
    end

    # Encodes a given value to a binary string.
    #
    # @param [String, Integer, Float, Array] value a formatted value (String, Fixnum, etc..) or an array of numbers
    # @param [String] type the type (vr) of data to encode
    # @return [String] an encoded binary string
    #
    def encode(value, type)
      raise ArgumentError, "Invalid argument type. Expected string, got #{type.class}" unless type.is_a?(String)
      value = [value] unless value.is_a?(Array)
      return value.pack(vr_to_str(type))
    end

    # Encodes a value to a binary string and prepends it to the instance string.
    #
    # @param [String, Integer, Float, Array] value a formatted value (String, Fixnum, etc..) or an array of numbers
    # @param [String] type the type (vr) of data to encode
    #
    def encode_first(value, type)
      value = [value] unless value.is_a?(Array)
      @string = "#{value.pack(vr_to_str(type))}#{@string}"
    end

    # Encodes a value to a binary string and appends it to the instance string.
    #
    # @param [String, Integer, Float, Array] value a formatted value (String, Fixnum, etc..) or an array of numbers
    # @param [String] type the type (vr) of data to encode
    #
    def encode_last(value, type)
      value = [value] unless value.is_a?(Array)
      @string = "#{@string}#{value.pack(vr_to_str(type))}"
    end

    # Appends a string with trailling spaces to achieve a target length, and encodes it to a binary string.
    #
    # @param [String] string a string to be padded
    # @param [Integer] target_length the target length of the string
    # @return [String] an encoded binary string
    #
    def encode_string_with_trailing_spaces(string, target_length)
      length = string.length
      if length < target_length
        return "#{[string].pack(@str)}#{['20'*(target_length-length)].pack(@hex)}"
      elsif length == target_length
        return [string].pack(@str)
      else
        raise "The specified string is longer than the allowed maximum length (String: #{string}, Target length: #{target_length})."
      end
    end

    # Encodes a tag from the ruby-dicom format ('GGGG,EEEE') to a proper binary string.
    #
    # @param [String] tag a ruby-dicom type tag string
    # @return [String] an encoded binary string
    #
    def encode_tag(tag)
      [
        @equal_endian ? "#{tag[2..3]}#{tag[0..1]}#{tag[7..8]}#{tag[5..6]}" : "#{tag[0..3]}#{tag[5..8]}"
      ].pack(@hex)
    end

    # Encodes a value, and if the the resulting binary string has an
    # odd length, appends a proper padding byte to make it even length.
    #
    # @param [String, Integer, Float, Array] value a formatted value (String, Fixnum, etc..) or an array of numbers
    # @param [String] vr the value representation of data to encode
    # @return [String] the encoded binary string
    #
    def encode_value(value, vr)
      if vr == 'AT'
        bin = encode_tag(value)
      else
        # Make sure the value is in an array:
        value = [value] unless value.is_a?(Array)
        # Get the proper pack string:
        type = vr_to_str(vr)
        # Encode:
        bin = value.pack(type)
        # Add an empty byte if the resulting binary has an odd length:
        bin = "#{bin}#{@pad_byte[vr]}" if bin.length.odd?
      end
      return bin
    end

    # Sets the endianness of the instance string. The relationship between the string
    # endianness and the system endianness determines which encoding/decoding flags to use.
    #
    # @param [Boolean] string_endian the endianness of the instance string (true for big endian, false for small endian)
    #
    def endian=(string_endian)
      @str_endian = string_endian
      configure_endian
      set_pad_byte
      set_string_formats
      set_format_hash
    end

    # Extracts the entire instance string, or optionally,
    # just the first part of it if a length is specified.
    #
    # @note The exported string is removed from the instance string.
    # @param [Integer] length the length of the string to cut out (if nil, the entire string is exported)
    # @return [String] the instance string (or part of it)
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

    # Extracts and returns a binary string of the given length, starting at the index position.
    # The instance index is then offset in accordance with the length read.
    #
    # @param [Integer] length the length of the string to be extracted
    # @return [String] a part of the instance string
    #
    def extract(length)
      str = @string.slice(@index, length)
      skip(length)
      return str
    end

    # Gives the length of the instance string.
    #
    # @return [Integer] the instance string's length
    #
    def length
      return @string.length
    end

    # Calculates the remaining length of the instance string (from the index position).
    #
    # @return [Integer] the remaining length of the instance string
    #
    def rest_length
      length = @string.length - @index
      return length
    end

    # Extracts the remaining part of the instance string (from the index position to the end of the string).
    #
    # @return [String] the remaining part of the instance string
    #
    def rest_string
      str = @string[@index..(@string.length-1)]
      return str
    end

    # Resets the instance string and index.
    #
    def reset
      @string = ''
      @index = 0
    end

    # Resets the instance index.
    #
    def reset_index
      @index = 0
    end

    # Sets the instance file variable.
    #
    # @note For performance reasons, we enable the Stream instance to write directly to file,
    #   to avoid expensive string operations which will otherwise slow down the write performance.
    #
    # @param [File] file a File object
    #
    def set_file(file)
      @file = file
    end

    # Sets a new instance string, and resets the index variable.
    #
    # @param [String] binary an encoded string
    #
    def set_string(binary)
      binary = binary[0] if binary.is_a?(Array)
      @string = binary
      @index = 0
    end

    # Applies an offset (positive or negative) to the instance index.
    #
    # @param [Integer] offset the length to skip (positive) or rewind (negative)
    #
    def skip(offset)
      @index += offset
    end

    # Writes a binary string to the File object of this instance.
    #
    # @param [String] binary a binary string
    #
    def write(binary)
      @file.write(binary)
    end


    private


    # Determines the relationship between system and string endianness, and sets the instance endian variable.
    #
    def configure_endian
      if CPU_ENDIAN == @str_endian
        @equal_endian = true
      else
        @equal_endian = false
      end
    end

    # Converts a data type/vr to an encode/decode string used by Ruby's pack/unpack methods.
    #
    # @param [String] vr a value representation (data type)
    # @return [String] an encode/decode format string
    #
    def vr_to_str(vr)
      unless @format[vr]
        errors << "Warning: Element type #{vr} does not have a reading method assigned to it. Something is not implemented correctly or the DICOM data analyzed is invalid."
        return @hex
      else
        return @format[vr]
      end
    end

    # Sets the hash which is used to convert data element types (VR) to
    # encode/decode format strings accepted by Ruby's pack/unpack methods.
    #
    def set_format_hash
      @format = {
        'BY' => @by, # Byte/Character (1-byte integers)
        'US' => @us, # Unsigned short (2 bytes)
        'SS' => @ss, # Signed short (2 bytes)
        'UL' => @ul, # Unsigned long (4 bytes)
        'SL' => @sl, # Signed long (4 bytes)
        'FL' => @fs, # Floating point single (4 bytes)
        'FD' => @fd, # Floating point double (8 bytes)
        'OB' => @by, # Other byte string (1-byte integers)
        'OF' => @fs, # Other float string (4-byte floating point numbers)
        'OW' => @us, # Other word string (2-byte integers)
        'AT' => @hex, # Tag reference (4 bytes) NB: For tags the spesialized encode_tag/decode_tag methods are used instead of this lookup table.
        'UN' => @hex, # Unknown information (header element is not recognized from local database)
        'HEX' => @hex, # HEX
        # We have a number of VRs that are decoded as string:
        'AE' => @str,
        'AS' => @str,
        'CS' => @str,
        'DA' => @str,
        'DS' => @str,
        'DT' => @str,
        'IS' => @str,
        'LO' => @str,
        'LT' => @str,
        'PN' => @str,
        'SH' => @str,
        'ST' => @str,
        'TM' => @str,
        'UI' => @str,
        'UT' => @str,
        'STR' => @str
      }
    end

    # Sets the hash which is used to keep track of which bytes to use for padding
    # data elements of various vr which have an odd value length.
    #
    def set_pad_byte
      @pad_byte = {
        # Space character:
        'AE' => "\x20",
        'AS' => "\x20",
        'CS' => "\x20",
        'DA' => "\x20",
        'DS' => "\x20",
        'DT' => "\x20",
        'IS' => "\x20",
        'LO' => "\x20",
        'LT' => "\x20",
        'PN' => "\x20",
        'SH' => "\x20",
        'ST' => "\x20",
        'TM' => "\x20",
        'UT' => "\x20",
        # Zero byte:
        'AT' => "\x00",
        'BY' => "\x00",
        'FL' => "\x00",
        'FD' => "\x00",
        'OB' => "\x00",
        'OF' => "\x00",
        'OW' => "\x00",
        'SL' => "\x00",
        'SQ' => "\x00",
        'SS' => "\x00",
        'UI' => "\x00",
        'UL' => "\x00",
        'UN' => "\x00",
        'US' => "\x00"
      }
    end

    # Sets the pack/unpack format strings that are used for encoding/decoding.
    # Some of these depends on the endianness of the system and the encoded string.
    #
    def set_string_formats
      if @equal_endian
        # Little endian byte order:
        @us = 'S<*' # Unsigned short (2 bytes)
        @ss = 's<*' # Signed short (2 bytes)
        @ul = 'L<*' # Unsigned long (4 bytes)
        @sl = 'l<*' # Signed long (4 bytes)
        @fs = 'e*' # Floating point single (4 bytes)
        @fd = 'E*' # Floating point double ( 8 bytes)
      else
        # Network (big endian) byte order:
        @us = 'S>*'
        @ss = 's>*'
        @ul = 'L>*'
        @sl = 'l>'
        @fs = 'g*'
        @fd = 'G*'
      end
      # Format strings that are not dependent on endianness:
      @by = 'C*' # Unsigned char (1 byte)
      @str = 'a*'
      @hex = 'H*' # (this may be dependent on endianness(?))
    end

  end
end