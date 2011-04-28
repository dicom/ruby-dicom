# encoding: UTF-8

# This file contains extensions to the Ruby library which are used by Ruby DICOM.

# Extension to the String class. These extensions are focused on processing/analysing Data Element tags.
# A tag string (as used by the Ruby DICOM library) is 9 characters long and of the form "GGGG,EEEE"
# (where G represents a group hexadecimal, and E represents an element hexadecimal).
#
class String

  # Renames the original unpack method.
  #
  alias __original_unpack__ unpack

  # Divides a string into a number of sub-strings of exactly equal length, and returns these in an array.
  # The length of self must be a multiple of parts, or an error will be raised.
  #
  def divide(parts)
    raise ArgumentError, "Expected an integer (Fixnum). Got #{parts.class}." unless parts.is_a?(Fixnum)
    raise ArgumentError, "Argument must be in the range <1 - self.length (#{self.length})>. Got #{parts}." if parts < 1 or parts > self.length
    raise ArgumentError, "Length of self (#{self.length}) must be a multiple of parts (#{parts})." unless (self.length/parts).to_f == self.length/parts.to_f
    if parts > 1
      sub_strings = Array.new
      sub_length = self.length/parts
      parts.times { sub_strings << self.slice!(0..(sub_length-1)) }
      return sub_strings
    else
      return [self]
    end
  end

  # Returns the element part of the tag string: The last 4 characters.
  #
  def element
    return self[5..8]
  end

  # Returns the group part of the tag string: The first 4 characters.
  #
  def group
    return self[0..3]
  end

  # Returns the "Group Length" ("GGGG,0000") tag which corresponds to the original tag/group string.
  # This string may either be a 4 character group string, or a 9 character custom tag.
  #
  def group_length
    if self.length == 4
      return self + ",0000"
    else
      return self.group + ",0000"
    end
  end

  # Checks if the string is a "Group Length" tag (its element part is "0000").
  # Returns true if it is and false if not.
  #
  def group_length?
    return (self.element == "0000" ? true : false)
  end

  # Checks if the string is a private tag (has an odd group number).
  # Returns true if it is, false if not.
  #
  def private?
    #return ((self.upcase =~ /\A\h{3}[1,3,5,7,9,B,D,F],\h{4}\z/) == nil ? false : true) # (incompatible with ruby 1.8)
    return ((self.upcase =~ /\A[a-fA-F\d]{3}[1,3,5,7,9,B,D,F],[a-fA-F\d]{4}\z/) == nil ? false : true)
  end

  # Checks if the string is a valid tag (as defined by Ruby DICOM: "GGGG,EEEE").
  # Returns true if it is a valid tag, false if not.
  #
  def tag?
    # Test that the string is composed of exactly 4 HEX characters, followed by a comma, then 4 more HEX characters:
    #return ((self.upcase =~ /\A\h{4},\h{4}\z/) == nil ? false : true) # (It turns out the hex reference '\h' isnt compatible with ruby 1.8)
    return ((self.upcase =~ /\A[a-fA-F\d]{4},[a-fA-F\d]{4}\z/) == nil ? false : true)
  end

  # Redefines the old unpack method, adding the ability to decode signed integers in big endian.
  #
  # === Parameters
  #
  # * <tt>string</tt> -- A template string which decides the decoding scheme to use.
  #
  def unpack(string)
    # Check for some custom unpack strings that we've invented:
    case string
      when "k*" # SS
        # Unpack BE US, repack LE US, then finally unpack LE SS:
        wrongly_unpacked = self.__original_unpack__("n*")
        repacked = wrongly_unpacked.__original_pack__("S*")
        correct = repacked.__original_unpack__("s*")
      when "r*" # SL
        # Unpack BE UL, repack LE UL, then finally unpack LE SL:
        wrongly_unpacked = self.__original_unpack__("N*")
        repacked = wrongly_unpacked.__original_pack__("I*")
        correct = repacked.__original_unpack__("l*")
      else
        # Call the original method for all other (normal) cases:
        self.__original_unpack__(string)
    end
  end

  # Will return true for all values
  # that LOOK like dicom names - they may not
  # be valid
  def dicom_name?
    self==self.titleize
  end

  # Will return true for all values
  # that LOOK like dicom method names - they
  # may not be valid
  def dicom_method?
    self==self.underscore
  end

  ## Will return a proper dicom method name
  def dicom_methodize #(char_set='ISO-8859-1')
=begin
    value = self
    unless char_set.nil?
      ic = Iconv.new('UTF-8//IGNORE', char_set)
      value = ic.iconv(value + ' ')[0..-2]
    end
  value.gsub(/^3/,'three_').gsub(/[#*?!]/,' ').gsub(', ',' ').gsub('Âµ','u').gsub('&','and').gsub(' - ','_').gsub(' / ','_').gsub(/[\s\-\.\,\/\\]/,'_').gsub(/[\(\)\']/,'').gsub(/\_+/, '_').downcase
=end
    self.gsub(/^3/,'three_').gsub(/[#*?!]/,' ').gsub(', ',' ').gsub('&','and').gsub(' - ','_').gsub(' / ','_').gsub(/[\s\-\.\,\/\\]/,'_').gsub(/[\(\)\']/,'').gsub(/\_+/, '_').downcase
  end

  # Capitalizes all the words and replaces some characters in the string to make a nicer looking title.
  #
  def titleize
    self.underscore.gsub(/_/, " ").gsub(/\b('?[a-z])/) { $1.capitalize }
  end

  # Makes an underscored, lowercase form from the string expression.
  #
  def underscore
    word = self.dup
    word.tr!("-", "_")
    word.downcase!
    word
  end

end


# Extensions to the Array class.
# These methods deal with encoding Integer arrays as well as conversion between signed and unsigned integers.
#
class Array

  # Renames the original pack method.
  #
  alias __original_pack__ pack

  # Redefines the old pack method, adding the ability to encode signed integers in big endian
  # (which surprisingly has not been supported out of the box in Ruby).
  #
  # === Parameters
  #
  # * <tt>string</tt> -- A template string which decides the encoding scheme to use.
  #
  def pack(string)
    # Check for some custom pack strings that we've invented:
    case string
      when "k*" # SS
        # Pack LE SS, re-unpack as LE US, then finally pack BE US:
        wrongly_packed = self.__original_pack__("s*")
        reunpacked = wrongly_packed.__original_unpack__("S*")
        correct = reunpacked.__original_pack__("n*")
      when "r*" # SL
        # Pack LE SL, re-unpack as LE UL, then finally pack BE UL:
        wrongly_packed = self.__original_pack__("l*")
        reunpacked = wrongly_packed.__original_unpack__("I*")
        correct = reunpacked.__original_pack__("N*")
      else
        # Call the original method for all other (normal) cases:
        self.__original_pack__(string)
    end
  end

  # Packs an array of (unsigned) integers to a binary string (blob).
  #
  # === Parameters
  #
  # * <tt>depth</tt> -- The bith depth to be used when encoding the unsigned integers.
  #
  def to_blob(depth)
    raise ArgumentError, "Expected Integer, got #{depth.class}" unless depth.is_a?(Integer)
    raise ArgumentError, "Unsupported bit depth #{depth}." unless [8,16].include?(depth)
    case depth
    when 8
      return self.pack("C*") # Unsigned char
    when 16
      return self.pack("S*") # Unsigned short, native byte order
    end
  end

  # Shifts the integer values of the array to make a signed data set.
  # The size of the shift is determined by the bit depth.
  #
  # === Parameters
  #
  # * <tt>depth</tt> -- The bith depth of the integers.
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
  # The size of the shift is determined by the bit depth.
  #
  # === Parameters
  #
  # * <tt>depth</tt> -- The bith depth of the integers.
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