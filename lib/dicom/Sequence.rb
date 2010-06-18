#    Copyright 2010 Christoffer Lervag

module DICOM

  # The Sequence class handles information related to a Sequence Element.
  #
  class Sequence < SuperParent

    # Include the Elements mixin module:
    include Elements

    # Initializes a Sequence instance.
    #
    def initialize(tag, options={})
      # Set common parent variables:
      initialize_parent
      # Set instance variables:
      @tag = tag
      @value = nil
      @name = options[:name]
      @vr = options[:vr] || "SQ"
      @bin = options[:bin]
      @length = options[:length] || -1
      if options[:parent]
        @parent = options[:parent]
        @parent.add(self)
      end
    end

  end # of class
end # of module