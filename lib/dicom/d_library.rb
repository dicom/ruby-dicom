#    Copyright 2008-2011 Christoffer Lervag

module DICOM

  # This class contains methods that interact with Ruby DICOM's dictionary.
  #
  class DLibrary

    # A hash containing tags as key and an array as value, where the array contains data element vr and name.
    attr_reader :tags
    # A hash containing UIDs as key and an array as value, where the array contains name and type.
    attr_reader :uid

    # Creates a DLibrary instance.
    #
    def initialize
      # Load the data elements hash, where the keys are tag strings, and values
      # are two-element arrays [vr, name] (where vr itself is an array of 1-3 elements):
      @tags = Dictionary.load_data_elements
      # Load UID hash (DICOM unique identifiers), where the keys are UID strings,
      # and values are two-element arrays [description, type]:
      @uid = Dictionary.load_uid
    end

    # Checks whether a given string is a valid transfer syntax or not.
    # Returns true if valid, false if not.
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- String. A DICOM UID value which will be matched against known transfer syntaxes.
    #
    def check_ts_validity(uid)
      result = false
      value = @uid[uid]
      if value
        result = true if value[1] == "Transfer Syntax"
      end
      return result
    end

    # Extracts, and returns, all transfer syntaxes and SOP Classes from the dictionary,
    # in the form of a transfer syntax hash and a sop class hash.
    #
    # Both hashes have UIDs as keys and their descriptions as values.
    #
    def extract_transfer_syntaxes_and_sop_classes
      transfer_syntaxes = Hash.new
      sop_classes = Hash.new
      @uid.each_pair do |key, value|
        if value[1] == "Transfer Syntax"
          transfer_syntaxes[key] = value[0]
        elsif value[1] == "SOP Class"
          sop_classes[key] = value[0]
        end
      end
      return transfer_syntaxes, sop_classes
    end

    # Checks if the specified transfer syntax implies the presence of pixel compression.
    # Returns true if pixel compression is implied, false if not.
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- String. A DICOM UID value.
    #
    def get_compression(uid)
      raise ArgumentError, "Expected String, got #{uid.class}" unless uid.is_a?(String)
      result = false
      value = @uid[uid]
      if value
        first_word = value[0].split(" ").first
        result = true if value[1] == "Transfer Syntax" and not ["Implicit", "Explicit"].include?(first_word)
      end
      return result
    end

    # Determines, and returns, the name and vr of the data element which the specified tag belongs to.
    # Values are retrieved from the Ruby DICOM dictionary if a match is found.
    #
    # === Notes
    #
    # * Private tags will have their names listed as "Private".
    # * Non-private tags that are not found in the dictionary will be listed as "Unknown".
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
    #
    def get_name_vr(tag)
      if tag.private? and tag.element != GROUP_LENGTH
        name = "Private"
        vr = "UN"
      else
        # Check the dictionary:
        values = @tags[tag]
        if values
          name = values[1]
          vr = values[0][0]
        else
          # For the tags that are not recognised, we need to do some additional testing to see if it is one of the special cases:
          if tag.element == GROUP_LENGTH
            # Group length:
            name = "Group Length"
            vr = "UL"
          elsif tag[0..6] == "0020,31"
            # Source Image ID's (Retired):
            values = @tags["0020,31xx"]
            name = values[1]
            vr = values[0][0]
          elsif tag.group == "1000" and tag.element =~ /\A\h{3}[0-5]\z/
            # Group 1000,xxx[0-5] (Retired):
            new_tag = tag.group + "xx" + tag.element[3..3]
            values = @tags[new_tag]
          elsif tag.group == "1010"
            # Group 1010,xxxx (Retired):
            new_tag = tag.group + "xxxx"
            values = @tags[new_tag]
          elsif tag[0..1] == "50" or tag[0..1] == "60"
            # Group 50xx (Retired) and 60xx:
            new_tag = tag[0..1]+"xx"+tag[4..8]
            values = @tags[new_tag]
            if values
              name = values[1]
              vr = values[0][0]
            end
          elsif tag[0..1] == "7F" and tag[5..6] == "00"
            # Group 7Fxx,00[10,11,20,30,40] (Retired):
            new_tag = tag[0..1]+"xx"+tag[4..8]
            values = @tags[new_tag]
            if values
              name = values[1]
              vr = values[0][0]
            end
          end
          # If none of the above checks yielded a result, the tag is unknown:
          unless name
            name = "Unknown"
            vr = "UN"
          end
        end
      end
      return name, vr
    end

    # Returns the tag that matches the supplied data element name, by searching the Ruby DICOM dictionary.
    # Returns nil if no match is found.
    #
    # === Parameters
    #
    # * <tt>name</tt> -- String. A data element name.
    #
    def get_tag(name)
      tag = nil
      @tags.each_pair do |key, value|
        tag = key if value[1] == name
      end
      return tag
    end

    # Returns the description/name of a specified UID (i.e. a transfer syntax or SOP class).
    # Returns nil if no match is found
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- String. A DICOM UID value.
    #
    def get_syntax_description(uid)
      name = nil
      value = @uid[uid]
      name = value[0] if value
      return name
    end

    # Checks the validity of the specified transfer syntax UID and determines the
    # encoding settings (explicitness & endianness) associated with this value.
    # The results are returned as 3 booleans: validity, explicitness & endianness.
    #
    # === Parameters
    #
    # * <tt>uid</tt> -- String. A DICOM UID value.
    #
    def process_transfer_syntax(uid)
      valid = check_ts_validity(uid)
      case uid
        # Some variations with uncompressed pixel data:
        when IMPLICIT_LITTLE_ENDIAN
          explicit = false
          endian = false
        when EXPLICIT_LITTLE_ENDIAN
          explicit = true
          endian = false
        when "1.2.840.10008.1.2.1.99" # Deflated Explicit VR, Little Endian
          # Note: Has this transfer syntax been tested yet?
          explicit = true
          endian = false
        when EXPLICIT_BIG_ENDIAN
          explicit = true
          endian = true
        else
          # For everything else, assume compressed pixel data, with Explicit VR, Little Endian:
          explicit = true
          endian = false
      end
      return valid, explicit, endian
    end

  end
end