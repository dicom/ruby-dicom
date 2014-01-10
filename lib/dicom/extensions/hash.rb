# Extensions to the Hash class used by the dicom gem.
#
class Hash

  # Creates a gap in the integer keys at the specified index.
  # This is achieved by incrementing by one all existing index keys that are equal or
  # bigger than the given index.
  #
  # @note It is assumed that this hash features integers as keys and items as values!
  # @param [Integer] index the index at which to clear
  # @return [Hash] the modified self
  #
  def create_key_gap_at(index)
    # Extract existing Hash entries to an array:
    pairs = self.sort
    h = Hash.new
    # Change the key of those equal or larger than index and put these key,value pairs back in a new Hash:
    pairs.each do |pair|
      if pair[0] < index
        # The key keeps its old index:
        h[pair[0]] = pair[1]
      else
        # The key (and the value Item) gets its index incremented by one:
        h[pair[0]+1] = pair[1]
        pair[1].index = pair[0]+1
      end
    end
    h
  end

end