#    Copyright 2010 Christoffer Lervag

module DICOM

  # Class for handling information related to a Sequence Element.
  class Sequence < SuperParent

    # Include the Elements mixin module:
    include Elements

    def initialize(tag, options={})
      # Set common parent variables:
      initialize_parent
      # Set instance variables:
      @tag = tag
      @value = nil
      @name = options[:name]
      @vr = options[:vr]
      @bin = options[:bin]
      @length = options[:length]
      if options[:parent]
        @parent = options[:parent]
        @parent.add(self)
      end
    end

  end # of class
end # of module