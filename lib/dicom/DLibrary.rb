#    Copyright 2008-2010 Christoffer Lervag

module DICOM

  # This class contains methods that interact with the DICOM dictionary.
  class DLibrary

    attr_reader :tags, :uid

    # Initializes the library instance.
    def initialize
      # Load the data elements hash, where the keys are tag strings, and values
      # are two-element arrays [vr, name] (where vr itself is an array of 1-3 elements).
      @tags = Dictionary.load_data_elements
      # Load UID hash (DICOM unique identifiers), where the keys are UID strings,
      # and values are two-element arrays [description, type].
      @uid = Dictionary.load_uid
    end

    # Checks whether a given string is a valid transfer syntax or not.
    def check_ts_validity(uid)
      result = false
      value = @uid[uid.rstrip]
      if value
        if value[1] == "Transfer Syntax"
          # Proved valid:
          result = true
        end
      end
      return result
    end

    # Extracts all transfer syntaxes and SOP Classes from the Dictionary and returns them in two separate Hashes.
    # Both Hashes have UIDs as keys and their descriptions as values.
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

    # Checks if the supplied transfer syntax indicates the presence of pixel compression or not.
    def get_compression(uid)
      result = false
      if uid
        value = @uid[uid.rstrip]
        if value
          if value[1] == "Transfer Syntax" and not value[0].include?("Endian")
            # It seems we have compression:
            result = true
          end
        end
      end
      return result
    end

    # Returns data element name and value representation from the dictionary unless the data element
    # is private. If a non-private tag is not recognized, "Unknown Name" and "UN" is returned.
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
            name = "Unknown Name"
            vr = "UN"
          end
        end
      end
      return name, vr
    end

    # Returns the tag that matches the supplied data element name, or if a tag is supplied, return that tag.
    # (This method may be considered for removal: Does the usefulnes of being able to create a tag by Name,
    # outweigh the performance impact of having this method?)
    def get_tag(tag_or_name)
      tag = false
      # The supplied value should be a string:
      if tag_or_name.is_a?(String)
        if tag_or_name.tag?
          tag = tag_or_name
        else
          # We have presumably been dealt a name. Search the dictionary to see if we can identify this name and return its corresponding tag:
          @tags.each_pair do |key, value|
            tag = key if value[1] == tag_or_name
          end
        end
      end
      return tag
    end

    # Returns the description/name of a specified UID (i.e. a transfer syntax or SOP class).
    def get_syntax_description(uid)
      value = @uid[uid]
      value = value[0] if value
      return value
    end

    # Returns the name/description corresponding to a given UID.
    def get_uid(uid)
      value = @uid[uid.rstrip]
      # Fetch the name of this UID:
      if value
        name = value[0]
      else
        name = "Unknown UID!"
      end
      return name
    end

    # Checks the Transfer Syntax UID and return the encoding settings associated with this value.
    def process_transfer_syntax(value)
      valid = check_ts_validity(value)
      case value
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


    # Following methods are private.
    #private

  end # of class
end # of module