#    Copyright 2010 Christoffer Lervag

module DICOM

  # Class for handling information related to an Item Element.
  class Item < SuperItem

    # Include the Elements mixin module:
    include Elements
    
    attr_accessor :index

    # Initializes an Item instance. Takes a Sequence as a parameter.
    #
    # === Parameters
    #
    def initialize(tag, options={})
      # Set common parent variables:
      initialize_parent
      # Set instance variables:
      @tag = tag
      @value = nil
      @name = options[:name] || "Item"
      @vr = options[:vr] || ITEM_VR
      @bin = options[:bin]
      @length = options[:length]
      @length = -1 unless options[:length] or options[:bin]
      if options[:parent]
        @parent = options[:parent]
        @parent.add_item(self, :index => options[:index])
      end
    end

    # Sets the binary string of a (Data) Item.
    def bin=(new_bin)
      if new_bin.is_a?(String)
        # Add an empty byte at the end if the length of the binary is odd:
        if new_bin.length[0] == 1
          @bin = new_bin + "\x00"
        else
          @bin = new_bin
        end
        @value = nil
        @length = @bin.length
      else
        raise "Invalid parameter type. String was expected, got #{new_bin.class}."
      end
    end

  end # of class
end # of module