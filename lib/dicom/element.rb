module DICOM

  # The Element class handles information related to ordinary (non-parent) elementals (data elements).
  #
  class Element

    # Include the Elemental mix-in module:
    include Elemental

    # Creates a Element instance.
    #
    # === Notes
    #
    # * In the case where the Element is given a binary instead of value, the Element will not have a formatted value (value = nil).
    # * Private data elements will have their names listed as "Private".
    # * Non-private data elements that are not found in the dictionary will be listed as "Unknown".
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A string which identifies the tag of the data element.
    # * <tt>value</tt> -- A custom value to be encoded as the data element binary string, or in some cases (specified by options), a pre-encoded binary string.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:bin</tt> -- String. If you already have the value pre-encoded to a binary string, the string can be supplied with this option to avoid it being encoded a second time.
    # * <tt>:encoded</tt> -- Boolean. If the value parameter contains a pre-encoded binary, this boolean must to be set as true.
    # * <tt>:name</tt> - String. The name of the Element may be specified upon creation. If it is not, the name will be retrieved from the dictionary.
    # * <tt>:parent</tt> - Item or DObject instance which the Element instance shall belong to.
    # * <tt>:vr</tt> -- String. If a private Element is created with a custom value, this must be specified to enable the encoding of the value. If it is not specified, the vr will be retrieved from the dictionary.
    #
    # === Examples
    #
    #   # Create a new data element and connect it to a DObject instance:
    #   patient_name = Element.new("0010,0010", "John Doe", :parent => dcm)
    #   # Create a "Pixel Data" element and insert image data that you have already encoded elsewhere:
    #   pixel_data = Element.new("7FE0,0010", processed_pixel_data, :encoded => true, :parent => dcm)
    #   # Create a private data element:
    #   private_data = Element.new("0011,2102", some_data, :parent => dcm, :vr => "LO")
    #
    def initialize(tag, value, options={})
      raise ArgumentError, "The supplied tag (#{tag}) is not valid. The tag must be a string of the form 'GGGG,EEEE'." unless tag.is_a?(String) && tag.tag?
      # Set instance variables:
      @tag = tag.upcase
      # We may beed to retrieve name and vr from the library:
      if options[:name] and options[:vr]
        @name = options[:name]
        @vr = options[:vr].upcase
      else
        name, vr = LIBRARY.name_and_vr(tag)
        @name = options[:name] || name
        @vr = (options[:vr] ? options[:vr].upcase : vr)
      end
      # Manage the parent relation if specified:
      if options[:parent]
        @parent = options[:parent]
        # FIXME: Because of some implementation problems, attaching the special
        # Data Set Trailing Padding element to a parent is not supported yet!
        @parent.add(self, :no_follow => true) unless @tag == 'FFFC,FFFC' && @parent.is_a?(Sequence)
      end
      # Value may in some cases be the binary string:
      unless options[:encoded]
        # The Data Element may have a value, have no value and no binary, or have no value and only binary:
        if value
          # Is binary value provided or do we need to encode it?
          if options[:bin]
            @value = value
            @bin = options[:bin]
          else
            if value == ''
              @value = value
              @bin = ''
            else
              # Set the value with our custom setter method to get proper encoding:
              self.value = value
            end
          end
        else
          # When no value is present, we set the binary as an empty string, unless the binary is specified:
          @bin = options[:bin] || ''
        end
      else
        @bin = value
      end
      # Let the binary decide the length:
      @length = @bin.length
    end

    # Returns true if the argument is an instance with attributes equal to self.
    #
    def ==(other)
      if other.respond_to?(:to_element)
        other.send(:state) == state
      end
    end

    alias_method :eql?, :==

    # Sets the binary string of a Element.
    #
    # === Notes
    #
    # If the specified binary has an odd length, a proper pad byte will automatically be appended
    # to give it an even length (which is needed to conform with the DICOM standard).
    #
    # === Parameters
    #
    # * <tt>new_bin</tt> -- A binary string of encoded data.
    #
    def bin=(new_bin)
      raise ArgumentError, "Expected String, got #{new_bin.class}." unless new_bin.is_a?(String)
      # Add a zero byte at the end if the length of the binary is odd:
      if new_bin.length.odd?
        @bin = new_bin + stream.pad_byte[@vr]
      else
        @bin = new_bin
      end
      @value = nil
      @length = @bin.length
    end

    # Checks if the Element actually has any child elementals.
    # Returns false, as Element instances by definition can not have children.
    #
    def children?
      return false
    end

    # Returns the endianness of the encoded binary value of this data element.
    # Returns false if little endian, true if big endian.
    #
    def endian
      return stream.str_endian
    end

    # Generates a Fixnum hash value for this instance.
    #
    def hash
      state.hash
    end

    # Returns a string containing a human-readable hash representation of the Element.
    #
    def inspect
      to_hash.inspect
    end

    # Checks if the Element is a parent.
    # Returns false, as Element instances by definition can not be parents.
    #
    def is_parent?
      return false
    end

    # Returns the value of the elemental (used as value in the parent's hash representation).
    #
    def to_hash
      return {self.send(DICOM.key_representation) => value}
    end

    # Returns self.
    #
    def to_element
      self
    end

    # Returns a json string containing a human-readable representation of the Element.
    #
    def to_json
      to_hash.to_json
    end

    # Returns a yaml string containing a human-readable representation of the Element.
    #
    def to_yaml
      to_hash.to_yaml
    end

    # The (decoded) value of the data element.
    #
    # === Notes
    #
    # Returned string values are automatically converted from their originally
    # encoding (e.g. ISO8859-1 or ASCII-8BIT) to UTF-8 for convenience reasons.
    # If the value string is wanted in its original encoding, extract the data
    # element's bin attribute instead.
    #
    # Note that according to the DICOM Standard PS 3.5 C.12.1.1.2, the Character Set only applies
    # to values of data elements of type SH, LO, ST, PN, LT or UT. Currently in ruby-dicom, all
    # string values are encoding converted regardless of VR, but whether this causes any problems is uknown.
    #
    def value
      if @value.is_a?(String)
        # Unless this is actually the Character Set data element,
        # get the character set (note that it may not be available):
        character_set = (@tag != '0008,0005' && top_parent.is_a?(DObject)) ? top_parent.value('0008,0005') : nil
        # Convert to UTF-8 from [original encoding]:
        # In most cases the original encoding is IS0-8859-1 (ISO_IR 100), but if
        # it is not specified in the DICOM object, or if the specified string
        # is not recognized, ASCII-8BIT is assumed.
        @value.encode('UTF-8', ENCODING_NAME[character_set] || 'ASCII-8BIT')
        # If unpleasant encoding exceptions occur, the below version may be considered:
        #@value.encode('UTF-8', ENCODING_NAME[character_set] || 'ASCII-8BIT', :invalid => :replace, :undef => :replace)
      else
        @value
      end
    end

    # Sets the value of the Element instance.
    #
    # === Notes
    #
    # In addition to updating the value attribute, the specified value is encoded to binary
    # and used to update the Element's bin and length attributes too.
    #
    # The specified value must be of a type that is compatible with the Element's value representation (vr).
    #
    # === Parameters
    #
    # * <tt>new_value</tt> -- A custom value (String, Fixnum, etc..) that is assigned to the Element.
    #
    def value=(new_value)
      conversion = VALUE_CONVERSION[@vr] || :to_s
      if conversion == :to_s
        # Unless this is actually the Character Set data element,
        # get the character set (note that it may not be available):
        character_set = (@tag != '0008,0005' && top_parent.is_a?(DObject)) ? top_parent.value('0008,0005') : nil
        # Convert to [DObject encoding] from [input string encoding]:
        # In most cases the DObject encoding is IS0-8859-1 (ISO_IR 100), but if
        # it is not specified in the DICOM object, or if the specified string
        # is not recognized, ASCII-8BIT is assumed.
        @value = new_value.to_s.encode(ENCODING_NAME[character_set] || 'ASCII-8BIT', new_value.to_s.encoding.name)
        @bin = encode(@value)
      else
        # We may have an array (of numbers) which needs to be passed directly to
        # the encode method instead of being forced into a numerical:
        if new_value.is_a?(Array)
          @value = new_value
          @bin = encode(@value)
        else
          @value = new_value.send(conversion)
          @bin = encode(@value)
        end
      end
      @length = @bin.length
    end


    # Following methods are private.
    private


    # Encodes a formatted value to a binary string and returns it.
    #
    # === Parameters
    #
    # * <tt>formatted_value</tt> -- A custom value (String, Fixnum, etc..).
    #
    def encode(formatted_value)
      return stream.encode_value(formatted_value, @vr)
    end

    # Returns the attributes of this instance in an array (for comparison purposes).
    #
    def state
      [@tag, @vr, @value, @bin]
    end

  end
end