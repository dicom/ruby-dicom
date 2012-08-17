module DICOM

  # This class contains methods that interact with Ruby DICOM's dictionary.
  #
  class DLibrary

    # A hash with element name strings as key and method name symbols as value.
    attr_reader :methods_from_names
    # A hash with element method name symbols as key and name strings as value.
    attr_reader :names_from_methods
    # A hash containing tags as key and an array as value, where the array contains data element vr and name.
    attr_reader :tags
    # A hash containing UIDs as key and an array as value, where the array contains name and type.
    attr_reader :uid

    # Creates a DLibrary instance.
    #
    def initialize
      # Load the elements dictionary:
      @tags = Hash.new
      File.open('dictionary/elements.txt').each do |record|
        fields = record.split("\t")
        @tags[fields[0]] = DictionaryElement.new(fields[0], fields[1], fields[2].split(","), fields[3], fields[4])
       end
      # Load the unique identifiers dictionary:
      @uid = Hash.new
      File.open('dictionary/uids.txt').each do |record|
        fields = record.split("\t")
        # Use UIDs as key and [name, type] as value:
        @uid[fields[0]] = [fields[1], fields[2]]
       end
      create_method_conversion_tables
    end

    # Returns the method (symbol) corresponding to the specified string value (which may represent a element tag, name or method).
    # Returns nil if no match is found.
    #
    def as_method(value)
      case true
      when value.tag?
        name, vr = get_name_vr(value)
        @methods_from_names[name]
      when value.dicom_name?
        @methods_from_names[value]
      when value.dicom_method?
        @names_from_methods.has_key?(value.to_sym) ? value.to_sym : nil
      else
        nil
      end
    end

    # Returns the name (string) corresponding to the specified string value (which may represent a element tag, name or method).
    # Returns nil if no match is found.
    #
    def as_name(value)
      case true
      when value.tag?
        name, vr = get_name_vr(value)
        name
      when value.dicom_name?
        @methods_from_names.has_key?(value) ? value.to_s : nil
      when value.dicom_method?
        @names_from_methods[value.to_sym]
      else
        nil
      end
    end

    # Returns the tag (string) corresponding to the specified string value (which may represent a element tag, name or method).
    # Returns nil if no match is found.
    #
    def as_tag(value)
      case true
      when value.tag?
        name, vr = get_name_vr(value)
        name.nil? ? nil : value
      when value.dicom_name?
        get_tag(value)
      when value.dicom_method?
        get_tag(@names_from_methods[value.to_sym])
      else
        nil
      end
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
        element = @tags[tag]
        if element
          name = element.name
          vr = element.vr
        else
          # For the tags that are not recognised, we need to do some additional testing to see if it is one of the special cases:
          if tag.element == GROUP_LENGTH
            # Create a group length element:
            element = DictionaryElement.new(tag, 'Group Length', ['UL'], '1', '')
            # Group length:
            #element = [["UL"], "Group Length"]
          elsif tag.group == "1000" and tag.element =~ /\A\h{3}[0-5]\z/
            # Group 1000,xxx[0-5] (Retired):
            new_tag = tag.group + ",xxx" + tag.element[3..3]
            de = @tags[new_tag]
            element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
          elsif tag.group == "1010"
            # Group 1010,xxxx (Retired):
            new_tag = tag.group + ",xxxx"
            de = @tags[new_tag]
            element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
          elsif tag[0..1] == "50" or tag[0..1] == "60"
            # Group 50xx (Retired) and 60xx:
            new_tag = tag[0..1]+"xx"+tag[4..8]
            de = @tags[new_tag]
            element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
          elsif tag[0..1] == "7F" and tag[5..6] == "00"
            # Group 7Fxx,00[10,11,20,30,40] (Retired):
            new_tag = tag[0..1]+"xx"+tag[4..8]
            de = @tags[new_tag]
            element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
          end
          # Extract name/vr, or if nothing matched, mark it as unknown:
          if element
            name = element.name
            vr = element.vr
          else
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
      name = name.to_s.downcase
      @tag_name_pairs_cache ||= Hash.new
      return @tag_name_pairs_cache[name] unless @tag_name_pairs_cache[name].nil?
      @tags.each_value do |element|
        next unless element.name.downcase == name
        tag = element.tag
        break
      end
      @tag_name_pairs_cache[name]=tag
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


    private


    # Creates the instance hashes that are used for name to/from method conversion.
    #
    def create_method_conversion_tables
      if @methods_from_names.nil?
        @methods_from_names = Hash.new
        @names_from_methods = Hash.new
        # Fill the hashes:
        @tags.each_value do |element|
          name = element.name
          method_name = name.dicom_methodize
          @methods_from_names[name] = method_name.to_sym
          @names_from_methods[method_name.to_sym] = name
        end
      end
    end

  end
end