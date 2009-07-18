#    Copyright 2008-2009 Christoffer Lervag

module DICOM
  # Class which holds the methods that interact with the DICOM dictionary.
  class DLibrary

    attr_reader :de_tag, :de_vr, :de_name, :uid_value, :uid_name, :uid_type, :pi_type, :pi_description

    # Initialize the DRead instance.
    def initialize
      # Dictionary content will be stored in instance arrays.
      # Load the dictionary:
      dict = Dictionary.new
      # Data elements:
      de = dict.load_data_elements
      @de_tag = de[0]
      @de_vr = de[1]
      @de_name = de[2]
      # Photometric Interpretation:
      pi = dict.load_image_types
      @pi_type = pi[0]
      @pi_description = pi[1]
      # UID:
      uid = dict.load_uid
      @uid_value = uid[0]
      @uid_name = uid[1]
      @uid_type = uid[2]
    end


    # Returns data element name and value representation from library if data element is recognized, else it returns "Unknown Name" and "UN".
    def get_name_vr(tag)
      pos = get_pos(tag)
      if pos != nil
        name = @de_name[pos]
        vr = @de_vr[pos][0]
      else
        # For the tags that are not recognised, we need to do some additional testing to see if it is one of the special cases:
        # Split tag in group and element:
        group = tag[0..3]
        element = tag[5..8]
        # Check for group length:
        if element == "0000"
          name = "Group Length"
          vr = "UL"
        end
        # Source Image ID's: (Retired)
        if tag[0..6] == "0020,31"
          pos = get_pos("0020,31xx")
          name = @de_name[pos]
          vr = @de_vr[pos][0]
        end
        # Group 50xx (retired) and 60xx:
        if tag[0..1] == "50" or tag[0..1] == "60"
          pos = get_pos(tag[0..1]+"xx"+tag[4..8])
          if pos != nil
            name = @de_name[pos]
            vr = @de_vr[pos][0]
          end
        end
        # If none of the above checks yielded a result, the tag is unknown:
        if name == nil
          name = "Unknown Name"
          vr = "UN"
        end
      end
      return [name,vr]
    end


    # Returns the tag that matches the supplied data element name,
    # or if a tag is supplied, return that tag.
    def get_tag(value)
      tag = false
      # The supplied value should be a string:
      if value.is_a?(String)
        # Is it a tag?
        # A tag is a string with 9 characters, where the 5th character should be a comma.
        if value[4..4] == ',' and value.length == 9
          # This is a tag.
          # (Here it is possible to have some further logic to check the validity of the string as a tag.)
          tag = value
        else
          # We have presumably been dealt a name. Search the dictionary to see if we can identify
          # it along with its corresponding tag:
          pos = @de_name.index(value)
          tag = @de_tag[pos] unless pos == nil
        end
      end
      return tag
    end


    # Checks whether a given string is a valid transfer syntax or not.
    def check_ts_validity(value)
      result = false
      pos = @uid_value.index(value)
      if pos != nil
        if pos >= 1 and pos <= 34
          # Proved valid:
          result = true
        end
      end
      return result
    end


    # Returns the name corresponding to a given UID.
    def get_uid(value)
      # Find the position of the specified value in the array:
      pos = @uid_value.index(value)
      # Fetch the name of this UID:
      if pos != nil
        name = @uid_name[pos]
      else
        name = "Unknown UID!"
      end
      return name
    end


    # Checks if the supplied transfer syntax indicates the presence of pixel compression or not.
    def get_compression(value)
      res = false
      # Index less or equal to 4 means no compression.
      pos = @uid_value.index(value)
      if pos != nil
        if pos > 4
          # It seems we have compression:
          res = true
        end
      end
      return res
    end


    # Checks the Transfer Syntax UID and return the encoding settings associated with this value.
    def process_transfer_syntax(value)
      valid = check_ts_validity(value)
      case value
        # Some variations with uncompressed pixel data:
        when "1.2.840.10008.1.2"
          # Implicit VR, Little Endian
          explicit = false
          endian = false
        when "1.2.840.10008.1.2.1"
          # Explicit VR, Little Endian
          explicit = true
          endian = false
        when "1.2.840.10008.1.2.1.99"
          # Deflated Explicit VR, Little Endian
          #@msg += ["Warning: Transfer syntax 'Deflated Explicit VR, Little Endian' is untested. Unknown if this is handled correctly!"]
          explicit = true
          endian = false
        when "1.2.840.10008.1.2.2"
          # Explicit VR, Big Endian
          explicit = true
          endian = true
        else
          # For everything else, assume compressed pixel data, with Explicit VR, Little Endian:
          explicit = true
          endian = false
        end
        return [valid, explicit, endian]
    end


    # Following methods are private.
    private

    # Returns the position of the supplied data element name in the Dictionary array.
    def get_pos(tag)
      pos = @de_tag.index(tag)
      return pos
    end


  end # of class
end # of module