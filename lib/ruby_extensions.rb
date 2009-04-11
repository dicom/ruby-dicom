class Array
  
  # For some reason, the Ruby Array class does not have a method for
  # finding all indices of a given value contained in an array.
  def all_indices(array, value)
    result = []
    self.each do |pos|
      result << pos if array[pos] == value
    end
    result
  end
  
  # Similar to method above, but this one returns the position of all strings that contain the query string.
  def all_indices_partial_match(array, value)
    result = []
    self.each do |pos|
      result << pos if array[pos].include?(value)
    end
    result
  end

end