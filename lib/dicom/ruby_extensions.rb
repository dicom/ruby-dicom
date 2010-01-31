# This file contains extensions to the Ruby library which are used by Ruby DICOM.

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

class String

  # Check if a given string appears to be a valid tag (GGGG,EEEE) by regexp matching.
  # The method tests that the string is exactly composed of 4 HEX characters, followed by
	# a comma, then 4 new HEX characters, which constitutes the tag format used by Ruby DICOM.
  def is_a_tag?
    result = false
		#result = true if self =~ /\A\h{4},\h{4}\z/ # (turns out the hex reference '\h' isnt compatible with ruby 1.8)
    result = true if self =~ /\A[a-fA-F\d]{4},[a-fA-F\d]{4}\z/
    return result
  end

  # Check if a given tag string indicates a private tag (Odd group number) by doing a regexp matching.
  def private?
    result = false
    #result = true if self.upcase =~ /\A\h{3}[1,3,5,7,9,B,D,F],\h{4}\z/ # (incompatible with ruby 1.8)
    result = true if self.upcase =~ /\A[a-fA-F\d]{3}[1,3,5,7,9,B,D,F],[a-fA-F\d]{4}\z/
    return result
  end

end
