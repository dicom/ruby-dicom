module DICOM

  # The Sequence class handles information related to Sequence elements.
  #
  class Sequence < Parent

    # Include the Elemental mix-in module:
    include Elemental

    # Creates a Sequence instance.
    #
    # === Notes
    #
    # * Private sequences will have their names listed as "Private".
    # * Non-private sequences that are not found in the dictionary will be listed as "Unknown".
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A string which identifies the tag of the sequence.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:length</tt> -- Fixnum. The Sequence length, which refers to the length of the encoded string of children of this Sequence.
    # * <tt>:name</tt> - String. The name of the Sequence may be specified upon creation. If it is not, the name will be retrieved from the dictionary.
    # * <tt>:parent</tt> - Item or DObject instance which the Sequence instance shall belong to.
    # * <tt>:vr</tt> -- String. The value representation of the Sequence may be specified upon creation. If it is not, a default vr is chosen.
    #
    # === Examples
    #
    #   # Create a new Sequence and connect it to a DObject instance:
    #   structure_set_roi = Sequence.new("3006,0020", :parent => obj)
    #   # Create an "Encapsulated Pixel Data" Sequence:
    #   encapsulated_pixel_data = Sequence.new("7FE0,0010", :name => "Encapsulated Pixel Data", :parent => obj, :vr => "OW")
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
        name, vr = LIBRARY.get_name_vr(tag)
        @name = options[:name] || name
        @vr = options[:vr] || "SQ"
      end
      @length = options[:length] || -1
      if options[:parent]
        @parent = options[:parent]
        @parent.add(self, :no_follow => true)
      end
    end

    # Returns true if the argument is an instance with attributes equal to self.
    #
    def ==(other)
      if other.respond_to?(:to_sequence)
        other.send(:state) == state
      end
    end

    alias_method :eql?, :==

    # Generates a Fixnum hash value for this instance.
    #
    def hash
      state.hash
    end

    # Returns self.
    #
    def to_sequence
      self
    end


    private


    # Returns the attributes of this instance in an array (for comparison purposes).
    #
    def state
      [@tag, @vr, @tags]
    end

  end
end