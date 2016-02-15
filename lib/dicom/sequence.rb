module DICOM

  # The Sequence class handles information related to Sequence elements.
  #
  class Sequence < Parent

    include Elemental
    include ElementalParent

    # Creates a Sequence instance.
    #
    # @note Private sequences are named as 'Private'.
    # @note Non-private sequences that are not found in the dictionary are named as 'Unknown'.
    #
    # @param [String] tag a ruby-dicom type element tag string
    # @param [Hash] options the options to use for creating the sequence
    # @option options [Integer] :length the sequence length, which refers to the length of the encoded string of children of this sequence
    # @option options [Integer] :name the name of the sequence may be specified upon creation (if it is not, the name is retrieved from the dictionary)
    # @option options [Integer] :parent an Item or DObject instance which the sequence instance shall belong to
    # @option options [Integer] :vr the value representation of the Sequence may be specified upon creation (if it is not, a default vr is chosen)
    #
    # @example Create a new Sequence and connect it to a DObject instance
    #   structure_set_roi = Sequence.new('3006,0020', :parent => dcm)
    # @example Create an "Encapsulated Pixel Data" Sequence
    #   encapsulated_pixel_data = Sequence.new('7FE0,0010', :name => 'Encapsulated Pixel Data', :parent => dcm, :vr => 'OW')
    #
    def initialize(tag, options={})
      raise ArgumentError, "The supplied tag (#{tag}) is not valid. The tag must be a string of the form 'GGGG,EEEE'." unless tag.is_a?(String) && tag.tag?
      # Set common parent variables:
      initialize_parent
      # Set instance variables:
      @tag = tag.upcase
      @value = nil
      @bin = nil
      # We may beed to retrieve name and vr from the library:
      if options[:name] and options[:vr]
        @name = options[:name]
        @vr = options[:vr]
      else
        name, vr = LIBRARY.name_and_vr(tag)
        @name = options[:name] || name
        @vr = options[:vr] || 'SQ'
      end
      @length = options[:length] || -1
      if options[:parent]
        @parent = options[:parent]
        @parent.add(self, :no_follow => true)
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
      if other.respond_to?(:to_sequence)
        other.send(:state) == state
      end
    end

    alias_method :eql?, :==

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
    # @return [Sequence] self
    #
    def to_sequence
      self
    end


    private


    # Collects the attributes of this instance.
    #
    # @return [Array<String, Item>] an array of attributes
    #
    def state
      [@tag, @vr, @tags]
    end

  end
end