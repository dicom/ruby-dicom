#    Copyright 2010 Christoffer Lervag

module DICOM

  # Super class which contains common code for both the Item and DObject classes.
  class SuperItem < SuperParent

    # Adds a Data or Sequence Element to self (self is either DObject or an Item).
    def add(element)
      @tags[element.tag] = element
    end

  end # of class
end # of module