# This file contains extensions to the Ruby library which are used by Ruby DICOM.

# Extension to the String class. These extensions are focused on processing/analysing Data Element tags.
# A tag string (as used by the Ruby DICOM library) is 9 characters long and of the form "GGGG,EEEE"
# (where G represents a group hexadecimal, and E represents an element hexadecimal).
#
class String

  # Renames the original unpack method.
  #
  alias __original_unpack__ unpack

  # Divides a string into a number of sub-strings of equal length, and returns these in an array.
  #
  def divide(parts)
    if parts > 1
      sub_strings = Array.new
      sub_length = self.length/parts
      parts.times do
        sub_strings << self.slice!(0..(sub_length-1))
      end
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

end


# Extensions to the Array class.
# These methods deal with decoding & encoding big endian signed integers,
# which is surprisingly not supported out of the box in Ruby.
#
class Array

  # Renames the original pack method.
  #
  alias __original_pack__ pack

  # Redefines the old pack method, adding the ability to encode signed integers in big endian.
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

end