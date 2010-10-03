# This file contains extensions to the Ruby library which are used by Ruby-DICOM.

# Extension to the String class. These extensions are focused on processing/analysing Data Element tags.
# A tag string (as used by the Ruby-DICOM library) is 9 characters long and of the form "GGGG,EEEE"
# (where G represents a group hexadecimal, and E represents an element hexadecimal).
#
class String

  # Renames the original unpack method.
  #
  alias __original_unpack__ unpack

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

  # Checks if the string is a valid tag (as defined by Ruby-DICOM: "GGGG,EEEE").
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
        wrong_sign = self.__original_unpack__("n*")
        correct = wrong_sign.to_signed(16)
      when "r*" # SL
        wrong_sign = self.__original_unpack__("N*")
        correct = wrong_sign.to_signed(32)
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
        converted = self.to_unsigned(16)
        converted.__original_pack__("n*")
      when "r*" # SL
        converted = self.to_unsigned(32)
        converted.__original_pack__("N*")
      else
        # Call the original method for all other (normal) cases:
        self.__original_pack__(string)
    end
  end

  # Converts an array of unsigned integers to signed integers.
  # Returns an array of signed integers.
  #
  # === Notes
  #
  # This is a hack to deal with the shortcomings of Ruby's built-in pack/unpack methods.
  #
  # === Parameters
  #
  # * <tt>bits</tt> -- An integer (Fixnum) which specifies the bit length of these integers.
  #
  def to_signed(bits)
    max_unsigned = 2 ** bits
    max_signed = 2 ** (bits - 1)
    sign_it = proc { |n| (n >= max_signed) ? n - max_unsigned : n }
    return self.collect!{|x| sign_it[x]}
  end

  # Converts an array of signed integers to unsigned integers.
  # Returns an array of unsigned integers.
  #
  # === Notes
  #
  # This is a hack to deal with the shortcomings of Ruby's built-in pack/unpack methods.
  #
  # === Parameters
  #
  # * <tt>bits</tt> -- An integer (Fixnum) which specifies the bit length of these integers.
  #
  def to_unsigned(bits)
    max_unsigned = 2 ** bits
    unsign_it = proc { |n| (n < 0) ? n + max_unsigned : n }
    return self.collect!{|x| unsign_it[x]}
  end

end