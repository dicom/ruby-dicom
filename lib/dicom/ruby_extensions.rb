# This file contains extensions to the Ruby library which are used by Ruby DICOM.

# Extension to the String class. These extensions are focused on processing/analysing Data Element tags.
# A tag string (as used by the Ruby DICOM library), is 9 characters long and of the form: "GGGG,EEEE"
#
class String

  # Returns the element part of the tag: The last 4 characters.
  #
  def element
    return self[5..8]
  end

  # Returns the group part of the tag: The first 4 characters.
  #
  def group
    return self[0..3]
  end

  # Replaces the element part of a tag string with four zero bytes. The resulting Group Length tag is returned.
  #
  def group_length
    if self.length == 4
      return self + ",0000"
    else
      return self.group + ",0000"
    end
  end

  # Checks if a given string equals a Group Length tag (its element part is "0000"). Returns true if it is a Group Length tag, false if not.
  #
  def group_length?
    return (self.element == "0000" ? true : false)
  end

  # Checks if a given tag string is private (has an odd group number). Returns true if private, false if not.
  #
  def private?
    #return ((self.upcase =~ /\A\h{3}[1,3,5,7,9,B,D,F],\h{4}\z/) == nil ? false : true) # (incompatible with ruby 1.8)
    return ((self.upcase =~ /\A[a-fA-F\d]{3}[1,3,5,7,9,B,D,F],[a-fA-F\d]{4}\z/) == nil ? false : true)
  end

  # Checks if a given string appears to be a valid tag by performing regexp matching. Returns true if it is a valid tag, false if not.
  #
  def tag?
    # Test that the string is composed of exactly 4 HEX characters, followed by a comma, then 4 more HEX characters:
    #return ((self.upcase =~ /\A\h{4},\h{4}\z/) == nil ? false : true) # (It turns out the hex reference '\h' isnt compatible with ruby 1.8)
    return ((self.upcase =~ /\A[a-fA-F\d]{4},[a-fA-F\d]{4}\z/) == nil ? false : true)
  end

end