#    Copyright 2008-2009 Christoffer Lervåg

module DICOM
  # Class which holds the methods that interact with the DICOM dictionary.
  class DLibrary

    attr_reader :de_label, :de_vr, :de_name, :uid_value, :uid_name, :uid_type, :pi_type, :pi_description

    # Initialize the DRead instance.
    def initialize()
      # Dictionary content will be stored in instance arrays.
      # Load the dictionary:
      dict = Dictionary.new()
      # Data elements:
      de = dict.load_tags()
      @de_label = de[0]
      @de_vr = de[1]
      @de_name = de[2]
      # Photometric Interpretation:
      pi = dict.load_image_types()
      @pi_type = pi[0]
      @pi_description = pi[1]
      # UID:
      uid = dict.load_uid()
      @uid_value = uid[0]
      @uid_name = uid[1]
      @uid_type = uid[2]
    end


    # Returns data element name and value representation from library if tag is recognised, else it returns "Unknown Name" and "UN".
    def get_name_vr(label)
      pos = get_pos(label)
      if pos != nil
        name = @de_name[pos]
        vr = @de_vr[pos][0]
      else
        # For the labels that are not recognised, we need to do some additional testing to see if it is one of the special cases:
        # Split label in group and element:
        group = label[0..3]
        element = label[5..8]
        # Check for group length:
        if element == "0000"
          name = "Group Length"
          vr = "UL"
        end
        # Source Image ID's: (Retired)
        if label[0..6] == "0020,31"
          pos = get_pos("0020,31xx")
          name = @de_name[pos]
          vr = @de_vr[pos][0]
        end
        # Group 50xx (retired) and 60xx:
        if label[0..1] == "50" or label[0..1] == "60"
          pos = get_pos(label[0..1]+"xx"+label[4..8])
          if pos != nil
            name = @de_name[pos]
            vr = @de_vr[pos][0]
          end
        end
        # If none of the above checks yielded a result, the label is unknown:
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
      return tag
    end


    # Checks whether a given string is a valid transfer syntax or not.
    def check_ts_validity(label)
      res = false
      pos = @uid_value.index(label)
      if pos != nil
        if pos >= 1 and pos <= 34
          # Proved valid:
          res = true
        end
      end
      return res
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


    # Following methods are private.
    private

    # Returns the position of the supplied data element name in the Dictionary array.
    def get_pos(label)
      pos = @de_label.index(label)
      return pos
    end


  end # end of class
end # end of module