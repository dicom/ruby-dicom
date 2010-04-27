# This file contains extensions to the Ruby library which are used by Ruby DICOM.

# Note: These array extensions may not be needed anymore after the rewrite.
class Array

  # Searching all indices, or a subset of indices, in an array, and returning all indices
  # where the array's value equals the queried value.
  def all_indices(array, value)
    result = []
    self.each do |pos|
      result << pos if array[pos] == value
    end
    return result
  end

  # Similar to method above, but this one returns the position of all strings that
  # contain the query string (exact match not required).
  def all_indices_partial_match(array, value)
    result = []
    self.each do |pos|
      result << pos if array[pos].include?(value)
    end
    return result
  end

end


# Extension to the String class. These extensions are focused on processing/analysing Data Element tags.
# A tag (as used by the Ruby DICOM library), is 9 characters long and of the form: GGGG,EEEE
class String

  # Returns the element part of the tag: The last 4 characters.
  def element
    return self[5..8]
  end

  # Returns the group part of the tag: The first 4 characters.
  def group
    return self[0..3]
  end
  
  # Checks if a given string appears to be a valid tag by performing regexp matching. Returns true or false based on the result.
  # The method tests that the string is exactly composed of 4 HEX characters, followed by a comma, then 4 more HEX characters.
  def is_a_tag?
    result = false
    #result = true if self =~ /\A\h{4},\h{4}\z/ # (turns out the hex reference '\h' isnt compatible with ruby 1.8)
    result = true if self =~ /\A[a-fA-F\d]{4},[a-fA-F\d]{4}\z/
    return result
  end

  # Check if a given tag string indicates a private tag (Odd group number) by performing a regexp matching.
  def private?
    result = false
    #result = true if self.upcase =~ /\A\h{3}[1,3,5,7,9,B,D,F],\h{4}\z/ # (incompatible with ruby 1.8)
    result = true if self.upcase =~ /\A[a-fA-F\d]{3}[1,3,5,7,9,B,D,F],[a-fA-F\d]{4}\z/
    return result
  end

end
