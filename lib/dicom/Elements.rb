#    Copyright 2010 Christoffer Lervag

module DICOM

  # This is a mix-in module which contains methods that are common among the different element types: Data, Item and Sequence.
  module Elements

      # Accessible element variables:
      attr_reader :bin, :length, :name, :parent, :tag, :vr

      # Returns the entire chain of parents in an array, where the first element is the
      # immediate parent and the last element is the top parent.
      # If no parents exist, an empty array is returned.
      def parents
        all_parents = Array.new
        # Extract all parents and add to array recursively:
        if parent
          all_parents = parent.parents if parent.parent
          all_parents.insert(0, parent)
        end
        return all_parents
      end

      # Sets the parent of this element to a referenced element.
      def parent=(new_parent)
        # Remove ourselves from the previous parent first:
        # Don't do this if parent is set as nil (by the remove method), or we'll get an endless loop!
        self.parent.remove(self.tag) if new_parent
        # Set the new parent (should we bother to test for parent validity here?):
        @parent = new_parent
      end
      
      # Returns the top parent of a particular Element. Unless an Element, or one of its parents, are independent, the top parent will be the DObject.
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