#    Copyright 2010-2011 Christoffer Lervag


module DICOM

  class << self

    #--
    # Module attributes:
    #++

    # The ruby-dicom image processor to be used.
    attr_accessor :image_processor
    # The key representation for hashes, json, yaml.
    attr_accessor :key_representation

    #--
    # Module methods:
    #++

    # Use tags as key. Example: "0010,0010"
    #
    def key_use_tags
      @key_representation = :tag
    end

    # Use names as key. Example: "Patient's Name"
    #
    def key_use_names
      @key_representation = :name
    end

    # Use method names as key. Example: :patients_name
    #
    def key_use_method_names
      @key_representation = :name_as_method
    end

  end

  #--
  # Default variable settings:
  #++

  # The default image processor.
  self.image_processor = :rmagick
  # The default key representation.
  self.key_representation = :name

end