module DICOM

  # The Elemental mix-in module contains methods that
  # are common among the various element type classes:
  # * Element
  # * Item
  # * Sequence
  #
  module Elemental

    # The encoded, binary value of the elemental (String).
    attr_reader :bin
    # The elemental's length (Fixnum).
    attr_reader :length
    # The elemental's name (String).
    attr_reader :name
    # The parent of this elemental (which may be an Item, Sequence or DObject).
    attr_reader :parent
    # The elemental's tag (String).
    attr_reader :tag
    # The elemental's value representation (String).
    attr_reader :vr

    # Gives the method (symbol) corresponding to the name string of this element.
    #
    # @return [Symbol, NilClass] the matched element method (or nil, if no match is made)
    #
    def name_as_method
      LIBRARY.as_method(@name)
    end

    # Retrieves the entire chain of parents connected to this elemental
    # (or an empty array, if the element is parent-less).
    #
    # @return [Array] array of parents (immediate parent first, top parent last)
    #
    def parents
      all_parents = Array.new
      # Extract all parents and add to array recursively:
      if parent
        all_parents = parent.parents if parent.parent
        all_parents.insert(0, parent)
      end
      return all_parents
    end

    # Sets a specified parent instance as this elemental's parent, while taking
    # care to delete this elemental from any previous parent, as well as adding
    # itself to the new parent (unless new parent is nil).
    #
    # @param [DObject, Item, Sequence, NilClass] new_parent the new parent object for this elemental
    # @example Create a new Sequence and connect it to a DObject instance
    #   structure_set_roi = Sequence.new("3006,0020")
    #   structure_set_roi.parent = dcm
    #
    def parent=(new_parent)
      # First take care of 'dependencies':
      if self.parent
        # Remove ourselves from the previous parent:
        if self.is_a?(Item)
          self.parent.delete(self.index, :no_follow => true)
        else
          self.parent.delete(self.tag, :no_follow => true)
        end
      end
      if new_parent
        # Add ourselves to the new parent:
        if self.is_a?(Item)
          new_parent.add_item(self, :no_follow => true)
        else
          new_parent.add(self, :no_follow => true)
        end
      end
      # Set the new parent (should we bother to test for parent validity here?):
      @parent = new_parent
    end

    # Sets a specified parent instance as this elemental's parent, without doing any other updates,
    # like removing the elemental from any previous parent or adding itself to the new parent.
    #
    # @param [DObject, Item, Sequence, NilClass] new_parent the new parent object for this elemental
    #
    def set_parent(new_parent)
      # Set the new parent (should we bother to test for parent validity here?):
      @parent = new_parent
    end

    # Returns a Stream instance which can be used for encoding a value to binary.
    #
    # @note Retrieves the Stream instance of the top parent DObject instance.
    #   If this fails, a new Stream instance is created (with little endian encoding assumed).
    #
    def stream
      if top_parent.is_a?(DObject)
        return top_parent.stream
      else
        return Stream.new(nil, file_endian=false)
      end
    end

    # Returns the top parent of a particular elemental.
    #
    # @note Unless the elemental, or one of its parent instances, are independent,
    #   the top parent will be a DObject instance.
    #
    def top_parent
      # The top parent is determined recursively:
      if parent
        if parent.is_a?(DObject)
          return parent
        else
          return parent.top_parent
        end
      else
        return self
      end
    end

  end

end