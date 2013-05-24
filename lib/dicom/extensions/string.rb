# encoding: UTF-8

# Extension to the String class. These mainly facilitate the processing and analysis of element tags.
# A tag string (as used by the ruby-dicom library) is 9 characters long and of the form 'GGGG,EEEE'
# (where G represents a group hexadecimal, and E represents an element hexadecimal).
#
class String

  # Renames the original unpack method.
  #
  alias __original_unpack__ unpack

  # Checks if a string value LOOKS like a DICOM name - it may still not be valid one.
  #
  # @return [Boolean] true if a string looks like a DICOM name, and false if not
  #
  def dicom_name?
    self == self.dicom_titleize
  end

  # Checks if a string value LOOKS like a DICOM method name - it may still not be valid one.
  #
  # @return [Boolean] true if a string looks like a DICOM method name, and false if not
  #
  def dicom_method?
    self == self.dicom_underscore
  end

  # Capitalizes all the words in the string and replaces some characters to make a nicer looking title.
  #
  # @return [String] a formatted, capitalized string
  #
  def dicom_titleize
    self.dicom_underscore.gsub(/_/, ' ').gsub(/\b('?[a-z])/) { $1.capitalize }
  end

  # Makes an underscored, lowercased version of the string.
  #
  # @return [String] an underscored, lower case string
  #
  def dicom_underscore
    word = self.dup
    word.tr!('-', '_')
    word.downcase!
    word
  end

  # Divides a string into a number of sub-strings of exactly equal length.
  #
  # @note The length of self must be a multiple of parts, or an exception will be raised.
  # @param [Integer] parts the number of sub-strings to create
  # @return [Array<String>] the divided sub-strings
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

  # Extracts the element part of the tag string: The last 4 characters.
  #
  # @return [String] the element part of the tag
  #
  def element
    return self[5..8]
  end

  # Returns the group part of the tag string: The first 4 characters.
  #
  # @return [String] the group part of the tag
  #
  def group
    return self[0..3]
  end

  # Returns the "Group Length" ('GGGG,0000') tag which corresponds to the original tag/group string.
  # The original string may either be a 4 character group string, or a 9 character custom tag.
  #
  # @return [String] a group length tag
  #
  def group_length
    if self.length == 4
      return self + ',0000'
    else
      return self.group + ',0000'
    end
  end

  # Checks if the string is a "Group Length" tag (its element part is '0000').
  #
  # @return [Boolean] true if it is a group length tag, and false if not
  #
  def group_length?
    return (self.element == '0000' ? true : false)
  end

  # Checks if the string is a private tag (has an odd group number).
  #
  # @return [Boolean] true if it is a private tag, and false if not
  #
  def private?
    return ((self.upcase =~ /\A\h{3}[1,3,5,7,9,B,D,F],\h{4}\z/) == nil ? false : true)
  end

  # Checks if the string is a valid tag (as defined by ruby-dicom: 'GGGG,EEEE').
  #
  # @return [Boolean] true if it is a valid tag, and false if not
  #
  def tag?
    # Test that the string is composed of exactly 4 HEX characters, followed by a comma, then 4 more HEX characters:
    return ((self.upcase =~ /\A\h{4},\h{4}\z/) == nil ? false : true)
  end

  # Converts the string to a proper DICOM element method name symbol.
  #
  # @return [Symbol] a DICOM element method name
  #
  def to_element_method
    self.gsub(/^3/,'three_').gsub(/[#*?!]/,' ').gsub(', ',' ').gsub('&','and').gsub(' - ','_').gsub(' / ','_').gsub(/[\s\-\.\,\/\\]/,'_').gsub(/[\(\)\']/,'').gsub(/\_+/, '_').downcase.to_sym
  end

  # Redefines the core library unpack method, adding
  # the ability to decode signed integers in big endian.
  #
  # @param [String] format a format string which decides the decoding scheme to use
  # @return [Array<String, Integer, Float>] the decoded values
  #
  def unpack(format)
    # Check for some custom unpack strings that we've invented:
    case format
      when "k*" # SS
        # Unpack BE US, repack LE US, then finally unpack LE SS:
        wrongly_unpacked = self.__original_unpack__('n*')
        repacked = wrongly_unpacked.__original_pack__('S*')
        correct = repacked.__original_unpack__('s*')
      when 'r*' # SL
        # Unpack BE UL, repack LE UL, then finally unpack LE SL:
        wrongly_unpacked = self.__original_unpack__('N*')
        repacked = wrongly_unpacked.__original_pack__('I*')
        correct = repacked.__original_unpack__('l*')
      else
        # Call the original method for all other (normal) cases:
        self.__original_unpack__(format)
    end
  end

end