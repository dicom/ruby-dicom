#    Copyright 2010 Christoffer Lervag

module DICOM

  # Class for handling information related to a Data Element.
  class DataElement

    # Include the Elements mixin module:
    include Elements
    
    attr_reader :value

    # Initialize a DataElement instance. Takes a tag string, a value and a hash of options as parameters.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A string which identifies the tag of  the Data Element.
    # * <tt>value</tt> -- A custom value to be encoded as the Data Element binary string, or in some cases, a pre-encoded binary string.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:bin</tt> -- String. If both value and binary string has already been decoded/encoded, the binary string can be supplied with this option to avoid it being processed again.
    # * <tt>:encoded</tt> -- Boolean. If the value parameter contains a pre-encoded binary, this boolean needs to be set. In this case the DataElement will not have a formatted value.
    # * <tt>:name</tt> - String. The name of the Data Element may be specified upon creation. If not, a query will be done against the library.
    # * <tt>:parent</tt> - Item or DObject instance which the newly created DataElement instance belongs to.
    # * <tt>:vr</tt> -- String. If a private Data Element is created with a custom value, this needs to be specified to enable the encoding of the value.
    def initialize(tag, value, options={})
      # Set instance variables:
      @tag = tag
      # We may beed to retrieve name and vr from the library:
      if options[:name] and options[:vr]
        @name = options[:name]
        @vr = options[:vr]
      else
        name, vr = LIBRARY.get_name_vr(tag)
        @name = options[:name] || name
        @vr = options[:vr] || vr
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
        @parent.add(self)
      end
    end

    # Set the binary string of a DataElement.
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

    # A boolean used to check whether whether or not an element actually has any child elements.
    # Returns false.
    def children?
      return false
    end

    # A boolean used to check whether or not an element is a parent.
    # Returns false.
    def is_parent?
      return false
    end

    # Set the value of a DataElement. The specified, formatted value will be encoded and the DataElement's binary string will be updated.
    def value=(new_value)
      @bin = encode(new_value)
      @value = new_value
      @length = @bin.length
    end

    # Following methods are private.
    private

    # Encodes a formatted value to binary and returns it.
    def encode(formatted_value)
      return stream.encode_value(formatted_value, @vr)
    end

    # Returns a Stream instance which can be used for encoding a value to binary.
    def stream
      # Use the stream instance of DObject or create a new one (with assumed Little Endian encoding)?
      if top_parent.is_a?(DObject)
        return top_parent.stream
      else
        return Stream.new(nil, file_endian=false)
      end
    end

  end # of class
end # of module