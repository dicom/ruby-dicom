#    Copyright 2008-2009 Christoffer Lervåg

# This file contains extensions to the Ruby library that is used by Ruby DICOM.

class Array
  
  # Searching all indices, or a subset of indices, in an array, and returning all indices
  # where the array's value equals the queried value.
  def all_indices(array, value)
    result = []
    self.each do |pos|
      result << pos if array[pos] == value
    end
    result
  end
  
  # Similar to method above, but this one returns the position of all strings that
  # contain the query string (exact match not required).
  def all_indices_partial_match(array, value)
    result = []
    self.each do |pos|
      result << pos if array[pos].include?(value)
    end
    result
  end

end