module DICOM

  # The Item class handles information related to items - the elements contained in sequences.
  #
  # === Inheritance
  #
  # As the Item class inherits from the ImageItem class, which itself inherits from the Parent class,
  # all ImageItem and Parent methods are also available to instances of Item.
  #
  class Item < ImageItem

    include Elemental
    include ElementalParent

    # The index of this Item in the group of items belonging to its parent. If the Item is without parent, index is nil.
    attr_accessor :index

    # Creates an Item instance.
    #
    # Normally, an Item contains data elements and/or sequences. However,
    # in some cases, an Item will instead/also carry binary string data,
    # like the pixel data of an encapsulated image fragment.
    #
    # @param [Hash] options the options to use for creating the item
    # @option options [String] :bin a binary string to be carried by the item
    # @option options [String] :indexif the item is to be inserted at a specific index (Item number), this option parameter needs to set
    # @option options [String] :length theiItem length (which either refers to the length of the encoded string of children of this item, or the length of its binary data)
    # @option options [String] :name the name of the item may be specified upon creation  (if not, a default name is used)
    # @option options [String] :parent a Sequence or DObject instance which the item instance shall belong to
    # @option options [String] :vr the value representation of the item may be specified upon creation (if not, a default vr is used)
    #
    # @example Create an empty Item and connect it to the "Structure Set ROI Sequence"
    #   item = Item.new(:parent => dcm["3006,0020"])
    # @example Create a "Pixel Data Item" which carries an encapsulated image frame (a pre-encoded binary)
    #   pixel_item = Item.new(:bin => processed_pixel_data, :parent => dcm["7FE0,0010"][1])
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

    # Checks for equality.
    #
    # Other and self are considered equivalent if they are
    # of compatible types and their attributes are equivalent.
    #
    # @param other an object to be compared with self.
    # @return [Boolean] true if self and other are considered equivalent
    #
    def ==(other)
      if other.respond_to?(:to_item)
        other.send(:state) == state
      end
    end

    alias_method :eql?, :==

    # Sets the binary string that the Item will contain.
    #
    # @param [String] new_bin a binary string of encoded data
    # @example Insert a custom jpeg in the (encapsulated) pixel data element (in it's first pixel data item)
    #   dcm['7FE0,0010'][1].children.first.bin = jpeg_binary_string
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

    # Computes a hash code for this object.
    #
    # @note Two objects with the same attributes will have the same hash code.
    #
    # @return [Fixnum] the object's hash code
    #
    def hash
      state.hash
    end

    # Returns self.
    #
    # @return [Item] self
    #
    def to_item
      self
    end


    private


    # Collects the attributes of this instance.
    #
    # @return [Array<String, Sequence, Element>] an array of attributes
    #
    def state
      [@vr, @name, @tags]
    end

  end
end