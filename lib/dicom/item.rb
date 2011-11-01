module DICOM

  # The Item class handles information related to items - the elements contained in sequences.
  #
  # === Inheritance
  #
  # As the Item class inherits from the ImageItem class, which itself inherits from the Parent class,
  # all ImageItem and Parent methods are also available to instances of Item.
  #
  class Item < ImageItem

    # Include the Elemental mix-in module:
    include Elemental

    # The index of this Item in the group of items belonging to its parent. If the Item is without parent, index is nil.
    attr_accessor :index

    # Creates an Item instance.
    #
    # === Notes
    #
    # Normally, an Item contains data elements and/or sequences. However, in some cases, an Item will instead/also
    # carry binary string data, like the pixel data of an encapsulated image fragment.
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:bin</tt> -- A binary string to be carried by the Item.
    # * <tt>:index</tt> -- Fixnum. If the Item is to be inserted at a specific index (Item number), this option parameter needs to set.
    # * <tt>:length</tt> -- Fixnum. The Item length (which either refers to the length of the encoded string of children of this Item, or the length of its binary data).
    # * <tt>:name</tt> - String. The name of the Item may be specified upon creation. If it is not, a default name is chosen.
    # * <tt>:parent</tt> - Sequence or DObject instance which the Item instance shall belong to.
    # * <tt>:vr</tt> -- String. The value representation of the Item may be specified upon creation. If it is not, a default vr is chosen.
    #
    # === Examples
    #
    #   # Create an empty Item and connect it to the "Structure Set ROI Sequence":
    #   item = Item.new(:parent => obj["3006,0020"])
    #   # Create a "Pixel Data Item" which carries an encapsulated image frame (a pre-encoded binary):
    #   pixel_item = Item.new(:bin => processed_pixel_data, :parent => obj["7FE0,0010"][1])
    #
    def initialize(options={})
      # Set common parent variables:
      initialize_parent
      # Set instance variables:
      @tag = ITEM_TAG
      @value = nil
      @name = options[:name] || "Item"
      @vr = options[:vr] || ITEM_VR
      if options[:bin]
        self.bin = options[:bin]
      else
        @length = options[:length] || -1
      end
      if options[:parent]
        @parent = options[:parent]
        @index = options[:index] if options[:index]
        @parent.add_item(self, :index => options[:index], :no_follow => true)
      end
    end

    # Sets the binary string that the Item will contain.
    #
    # === Parameters
    #
    # * <tt>new_bin</tt> -- A binary string of encoded data.
    #
    # === Examples
    #
    #   # Insert a custom jpeg in the (encapsulated) pixel data element, in it's first pixel data item:
    #   obj["7FE0,0010"][1].children.first.bin = jpeg_binary_string
    #
    def bin=(new_bin)
      raise ArgumentError, "Invalid parameter type. String was expected, got #{new_bin.class}." unless new_bin.is_a?(String)
      # Add an empty byte at the end if the length of the binary is odd:
      if new_bin.length.odd?
        @bin = new_bin + "\x00"
      else
        @bin = new_bin
      end
      @value = nil
      @length = @bin.length
    end

  end
end