module DICOM

  class << self

    #--
    # Module attributes:
    #++

    # The ruby-dicom image processor to be used.
    attr_accessor :image_processor
    # The key representation for hashes, json, yaml.
    attr_accessor :key_representation
    # Source Application Entity Title (gets written to the DICOM header in files where it is undefined).
    attr_accessor :source_app_title

    #--
    # Module methods:
    #++

    # Generates one or several random UID strings.
    # The UIDs are based on the RTKIT dicom_root attribute, a type prefix, a datetime part,
    # a random number part, and an index part (when multiple UIDs are requested,
    # e.g. for a SOP Instances in a Series).
    # Returns the UIDs in a string array.
    #
    # === Parameters
    #
    # * <tt>root</tt> -- String. The DICOM root UID to be used for generating the UID string, e.g. '1.2.840.999'.
    # * <tt>prefix</tt> -- String. A (numerical) string which is placed between the dicom root and the time/random part of the UID.
    #
    def generate_uid(root=UID, prefix=1)
      # NB! For UIDs, leading zeroes after a dot is not allowed, and must be removed:
      date = Time.now.strftime("%Y%m%d").to_i.to_s
      time = Time.now.strftime("%H%M%S").to_i.to_s
      random = rand(99999) + 1 # (Minimum 1, max. 99999)
      uid = [root, prefix, date, time, random].join('.')
      return uid
    end

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
  # The default source application entity title.
  self.source_app_title = "RUBY_DICOM"

end