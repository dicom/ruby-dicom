#    Copyright 2010-2011 Christoffer Lervag

module DICOM

  # The DataElement class handles information related to ordinary (non-parent) data elements.
  #
  class DataElement

    # Include the Elements mix-in module:
    include Elements

    # The (decoded) value of the data element.
    attr_reader :value

    # Creates a DataElement instance.
    #
    # === Notes
    #
    # * In the case where the DataElement is given a binary instead of value, the DataElement will not have a formatted value (value = nil).
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
    # * <tt>:name</tt> - String. The name of the DataElement may be specified upon creation. If it is not, the name will be retrieved from the dictionary.
    # * <tt>:parent</tt> - Item or DObject instance which the DataElement instance shall belong to.
    # * <tt>:vr</tt> -- String. If a private DataElement is created with a custom value, this must be specified to enable the encoding of the value. If it is not specified, the vr will be retrieved from the dictionary.
    #
    # === Examples
    #
    #   # Create a new data element and connect it to a DObject instance:
    #   patient_name = DataElement.new("0010,0010", "John Doe", :parent => obj)
    #   # Create a "Pixel Data" element and insert image data that you have already encoded elsewhere:
    #   pixel_data = DataElement.new("7FE0,0010", processed_pixel_data, :encoded => true, :parent => obj)
    #   # Create a private data element:
    #   private_data = DataElement.new("0011,2102", some_data, :parent => obj, :vr => "LO")
    #
    def initialize(tag, value, options={})
      raise ArgumentError, "The supplied tag (#{tag}) is not valid. The tag must be a string of the form 'GGGG,EEEE'." unless tag.is_a?(String) && tag.tag?
      # Set instance variables:
      @tag = tag
      # We may beed to retrieve name and vr from the library:
      if options[:name] and options[:vr]
        @name = options[:name]
        @vr = options[:vr].upcase
      else
        name, vr = LIBRARY.get_name_vr(tag)
        @name = options[:name] || name
        @vr = (options[:vr] ? options[:vr].upcase : vr)
      end
      # Value may in some cases be the binary string:
      unless options[:encoded]
        @value = value
        # The Data Element may have a value, have no value and no binary, or have no value and only binary:
        if value
          # Is binary value provided or do we need to encode it?
          if options[:bin]
            @bin = options[:bin]
          else
            @bin = encode(value)
          end
        else
          # When no value is present, we set the binary as an empty string, unless the binary is specified:
          @bin = options[:bin] || ""
        end
      else
        @bin = value
      end
      # Let the binary decide the length:
      @length = @bin.length
      # Manage the parent relation if specified:
      if options[:parent]
        @parent = options[:parent]
        @parent.add(self, :no_follow => true)
      end
    end

    # Sets the binary string of a DataElement.
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
      if new_bin.length[0] == 1
        @bin = new_bin + stream.pad_byte[@vr]
      else
        @bin = new_bin
      end
      @value = nil
      @length = @bin.length
    end

    # Checks if an element actually has any child elements.
    # Returns false, as DataElement instances can not have children.
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

    # Checks if an element is a parent.
    # Returns false, as DataElement instance can not be parents.
    #
    def is_parent?
      return false
    end

    # Sets the value of the DataElement instance.
    #
    # === Notes
    #
    # In addition to updating the value attribute, the specified value is encoded and used to
    # update both the DataElement's binary and length attributes too.
    #
    # The specified value must be of a type that is compatible with the DataElement's value representation (vr).
    #
    # === Parameters
    #
    # * <tt>new_value</tt> -- A custom value (String, Fixnum, etc..) that is assigned to the DataElement.
    #
    def value=(new_value)
      @bin = encode(new_value)
      @value = new_value
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

  end
end