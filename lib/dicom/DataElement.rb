#    Copyright 2008-2010 Christoffer Lervag

module DICOM

  # Class for handling information related to a Data Element.
  class DataElement

    # Include the Elements mixin module:
    include Elements

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
    # * <tt>:bin</tt> -- Boolean. If the value parameter contains a pre-encoded binary, this boolean needs to be set.
    # * <tt>:bin_data</tt> -- String. If both value and binary string has been decoded/encoded, this option can be supplied to avoid double processing.
    # * <tt>:name</tt> - String. The name of the Data Element may be specified upon creation. If not, a query will be done against the library.
    # * <tt>:parent</tt> - Item or DObject instance which the newly created DataElement instance belongs to.
    # * <tt>:vr</tt> -- String. If a private Data Element is created with a custom value, this needs to be specified to enable the encoding of the value.
    def initialize(tag, value, options={})
      # Set instance variables:
      @tag = tag
      @value = value
      @name = options[:name]
      @vr = options[:vr]
      @bin = options[:bin_data] || ""
      if options[:parent]
        @parent = options[:parent]
        @parent.add(self)
      end
      @length = @bin.length
    end

    # Returns false (a boolean used to check whether an element has children or not).
    def children?
      return false
    end

  end # of class
end # of module