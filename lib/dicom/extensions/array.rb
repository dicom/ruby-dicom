# Extensions to the Array class.
# These mainly deal with encoding integer arrays as well as conversion between
# signed and unsigned integers.
#
class Array

  # Renames the original pack method.
  #
  alias __original_pack__ pack

  # Redefines the old pack method, adding the ability to encode signed integers in big endian
  # (which surprisingly has not been supported out of the box in Ruby until version 1.9.3).
  #
  # @param [String] format a format string which decides the encoding scheme to use
  # @return [String] the encoded binary string
  #
  def pack(format)
    # FIXME: At some time in the future, when Ruby 1.9.3 can be set as required ruby version,
    # this custom pack (as well as unpack) method can be discarded, and the desired endian
    # encodings can probably be achieved with the new template strings introduced in 1.9.3.
    #
    # Check for some custom pack strings that we've invented:
    case format
      when 'k*' # SS
        # Pack LE SS, re-unpack as LE US, then finally pack BE US:
        wrongly_packed = self.__original_pack__('s*')
        reunpacked = wrongly_packed.__original_unpack__('S*')
        correct = reunpacked.__original_pack__('n*')
      when 'r*' # SL
        # Pack LE SL, re-unpack as LE UL, then finally pack BE UL:
        wrongly_packed = self.__original_pack__('l*')
        reunpacked = wrongly_packed.__original_unpack__('I*')
        correct = reunpacked.__original_pack__('N*')
      else
        # Call the original method for all other (normal) cases:
        self.__original_pack__(format)
    end
  end

  # Packs an array of (unsigned) integers to a binary string (blob).
  #
  # @param [Integer] depth the bit depth to be used when encoding the unsigned integers
  # @return [String] an encoded binary string
  #
  def to_blob(depth)
    raise ArgumentError, "Expected Integer, got #{depth.class}" unless depth.is_a?(Integer)
    raise ArgumentError, "Unsupported bit depth #{depth}." unless [8,16].include?(depth)
    case depth
    when 8
      return self.pack('C*') # Unsigned char
    when 16
      return self.pack('S*') # Unsigned short, native byte order
    end
  end

  # Shifts the integer values of the array to make a signed data set.
  # The size of the shift is determined by the given bit depth.
  #
  # @param [Integer] depth the bit depth of the integers
  # @return [Array<Integer>] an array of signed integers
  #
  def to_signed(depth)
    raise ArgumentError, "Expected Integer, got #{depth.class}" unless depth.is_a?(Integer)
    raise ArgumentError, "Unsupported bit depth #{depth}." unless [8,16].include?(depth)
    case depth
    when 8
      return self.collect {|i| i - 128}
    when 16
      return self.collect {|i| i - 32768}
    end
  end

  # Shifts the integer values of the array to make an unsigned data set.
  # The size of the shift is determined by the given bit depth.
  #
  # @param [Integer] depth the bit depth of the integers
  # @return [Array<Integer>] an array of unsigned integers
  #
  def to_unsigned(depth)
    raise ArgumentError, "Expected Integer, got #{depth.class}" unless depth.is_a?(Integer)
    raise ArgumentError, "Unsupported bit depth #{depth}." unless [8,16].include?(depth)
    case depth
    when 8
      return self.collect {|i| i + 128}
    when 16
      return self.collect {|i| i + 32768}
    end
  end

end