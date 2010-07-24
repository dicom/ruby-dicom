# This file contains extensions to the Ruby library which are used by Ruby DICOM.

# Extension to the String class. These extensions are focused on processing/analysing Data Element tags.
# A tag string (as used by the Ruby DICOM library) is 9 characters long and of the form "GGGG,EEEE"
# (where G represents a group hexadecimal, and E represents an element hexadecimal).
#
class String

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

end