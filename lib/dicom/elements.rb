#    Copyright 2010-2011 Christoffer Lervag

module DICOM

  # The Elements mix-in module contains methods that are common among the different element classes:
  # * DataElement
  # * Item
  # * Sequence
  #
  module Elements

      # The encoded, binary value of the element (String).
      attr_reader :bin
      # The element's length (Fixnum).
      attr_reader :length
      # The element's name (String).
      attr_reader :name
      # The parent of this element (which may be an Item, Sequence or DObject).
      attr_reader :parent
      # The elementss tag (String).
      attr_reader :tag
      # The element's value representation (String).
      attr_reader :vr

      # Retrieves the entire chain of parents connected to this element.
      # The parents are returned in an array, where the first element is the
      # immediate parent and the last element is the top parent.
      # Returns an empty array if no parent is defined.
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

      # Sets a specified element as this element's parent.
      #
      # === Parameters
      #
      # * <tt>new_parent</tt> -- A parent object (which can be either a DObject, Item or Sequence instance).
      #
      # === Examples
      #
      #   # Create a new Sequence and connect it to a DObject instance:
      #   structure_set_roi = Sequence.new("3006,0020")
      #   structure_set_roi.parent = obj
      #
      def parent=(new_parent)
        # Remove ourselves from the previous parent (if any) first:
        # Don't do this if parent is set as nil (by the remove method), or we'll get an endless loop!
        if self.parent
          self.parent.remove(self.tag) if new_parent and self.parent != new_parent
        end
        # Set the new parent (should we bother to test for parent validity here?):
        @parent = new_parent
      end

      # Returns the top parent of a particular element.
      #
      # === Notes
      #
      # Unless an element, or one of its parent elements, are independent, the top parent will be a DObject instance.
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