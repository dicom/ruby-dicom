#    Copyright 2010 Christoffer Lervag

module DICOM

  # Class for handling information related to an Item Element.
  class Item < SuperItem

    # Include the Elements mixin module:
    include Elements

    # Initializes an Item instance. Takes a Sequence as a parameter.
    #
    # === Parameters
    #
    def initialize(tag, value, options={})
      # Set common parent variables:
      initialize_parent
      # Set instance variables:
      @tag = tag
      @value = value
      @name = options[:name] || "Item"
      @vr = options[:vr] || ITEM_VR
      @bin = options[:bin_data]
      @length = options[:length]
      if options[:parent]
        @parent = options[:parent]
        @parent.add_item(self)
      end
    end

  end # of class
end # of module