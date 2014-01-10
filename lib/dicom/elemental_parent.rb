module DICOM

  # The ElementalParent mix-in module contains methods that are common among
  # the two elemental parent classes: Item & Sequence
  #
  module ElementalParent

    # Adds a child item to a Sequence (or Item in some cases where pixel data is encapsulated).
    #
    # If no existing Item is given, a new item will be created and added.
    #
    # @note Items are specified by index (starting at 0) instead of a tag string!
    #
    # @param [Item] item the Item instance to be added
    # @param [Hash] options the options used for adding the item
    # option options [Integer] :if specified, forces the item to be inserted at that specific index (Item number)
    # option options [Boolean] :no_follow when true, the method does not update the parent attribute of the child that is added
    # * <tt>options</tt> -- A hash of parameters.
    # @example Add an empty Item to a specific Sequence
    #   dcm["3006,0020"].add_item
    # @example Add an existing Item at the 2nd item position/index in the specific Sequence
    #   dcm["3006,0020"].add_item(my_item, :index => 1)
    #
    def add_item(item=nil, options={})
      if item
        if item.is_a?(Item)
          if index = options[:index]
            # This Item will take a specific index, and all existing Items with index higher or equal to this number will have their index increased by one.
            # Check if index is valid (must be an existing index):
            if index >= 0
              # If the index value is larger than the max index present, we dont need to modify the existing items.
              if index < @tags.length
                @tags = @tags.create_key_gap_at(index)
              else
                # Set the index value one higher than the already existing max value:
                index = @tags.length
              end
              #,Add the new Item and set its index:
              @tags[index] = item
              item.index = index
            else
              raise ArgumentError, "The specified index (#{index}) is out of range (must be a positive integer)."
            end
          else
            # Add the existing Item to this Sequence:
            index = @tags.length
            @tags[index] = item
            # Let the Item know what index key it's got in it's parent's Hash:
            item.index = index
          end
          # Set ourself as this item's new parent:
          item.set_parent(self) unless options[:no_follow]
        else
          raise ArgumentError, "Expected Item, got #{item.class}"
        end
      else
        # Create an empty item with self as parent:
        item = Item.new(:parent => self)
      end
    end

  end

end