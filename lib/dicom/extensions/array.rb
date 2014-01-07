# Extensions to the Array class.
# These mainly deal with encoding integer arrays as well as conversion between
# signed and unsigned integers.
#
class Array

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
      return self.pack('S<*') # Unsigned short, little endian byte order
    end
  end

  # Shifts the integer values of the array to make a signed data set.
  # The size of the shift is determined by the given bit depth.
  #
  # @param [Integer] depth the bit depth of the integers
  # @return [Array<Integer>] an array of signed integers
  #
  def to_signed(depth)
    case depth
    when 8
      self.collect {|i| i - 128}
    when 16
      self.collect {|i| i - 32768}
    else
      raise ArgumentError, "Unknown or unsupported bit depth: #{depth}"
    end
  end

  # Shifts the integer values of the array to make an unsigned data set.
  # The size of the shift is determined by the given bit depth.
  #
  # @param [Integer] depth the bit depth of the integers
  # @return [Array<Integer>] an array of unsigned integers
  #
  def to_unsigned(depth)
    case depth
    when 8
      self.collect {|i| i + 128}
    when 16
      self.collect {|i| i + 32768}
    else
      raise ArgumentError, "Unknown or unsupported bit depth: #{depth}"
    end
  end

end