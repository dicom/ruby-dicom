#    Copyright 2010 Christoffer Lervag

module DICOM

  # Super class which contains common code for all parent elements (Item, Sequence and DObject).
  class SuperParent

    attr_reader :children

    # Initialize common variables among the parent elements.
    def initialize_parent
      # All child data elements and sequences are stored in a hash where tag string is used as key:
      @tags = Hash.new
    end

    # Returns the child element, specified by a tag string in a Hash-like syntax.
    # If the requested tag doesn't exist, nil is returned.
    # NB! Only immediate children are searched. Grandchildren etc. are not included.
    def [](tag)
      return @tags[tag]
    end

    # Returns true (a boolean used to check whether an element has children or not).
    def children?
      return true
    end

    # Returns all (immediate) child elements in a sorted array.
    def child_array
      return @tags.sort
    end

    # Returns the number of Elements contained directly in this parent (does not include number of elements of possible children).
    def count
      return @tags.length
    end

    # Returns the total number of Elements contained in this parent (includes elements contained in possible child elements).
    def count_all
      # Search recursively through all child elements that are parents themselves.
      total_count = count
      @tags.each_value do |value|
        total_count += value.count_all if value.children?
      end
      return total_count
    end

    # Checks whether a given tag is defined for this parent. Returns true if a match is found, false if not.
    def exists?(tag)
      if @tags[tag]
        return true
      else
        return false
      end
    end

    # Prints the Elements contained in this parent to the screen.
    def print
      child_array.each do |child|
        # A two-element array where the first element is the tag string and the second is the Data/Item/Sequence element object.
        tag = child[0]
        element = child[1]
        puts "#{tag} #{element.name} #{element.vr} #{element.value}"
      end
    end

  end # of class
end # of module
