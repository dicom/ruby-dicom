#    Copyright 2010 Christoffer Lervag

module DICOM

  # Class for handling information related to a Sequence Element.
  class Sequence < SuperParent

    # Include the Elements mixin module:
    include Elements

    def initialize(tag, value, options={})
      # Set common parent variables:
      initialize_parent
      # Set instance variables:
      @tag = tag
      @value = value
      @name = options[:name]
      @vr = options[:vr]
      @bin = options[:bin_data]
      @length = options[:length]
      if options[:parent]
        @parent = options[:parent]
        @parent.add(self)
      end
    end

    # Adds a child item to this sequence.
    # If no existing Item is specified, an empty item will be added.
    # NB! Items are specified by index (starting at 1) instead of a tag string.
    def add_item(item=nil)
      if item
        if item.is_a?(Item)
          # Add the existing Item to this Sequence:
          index = @tags.length + 1
          @tags[index] = item
        else
          raise "The specified parameter is not an Item. Only Items are allowed to be added to a Sequence."
        end
      else
        # Create an empty Item with self as parent.
        index = @tags.length + 1
        item = Item.new(ITEM_TAG, 0, :parent => self)
      end
    end

  end # of class
end # of module