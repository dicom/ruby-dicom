module DICOM

  # This class contains methods that interact with ruby-dicom's dictionary data.
  #
  class DLibrary

    # A hash with element name strings as key and method name symbols as value.
    attr_reader :methods_from_names
    # A hash with element method name symbols as key and name strings as value.
    attr_reader :names_from_methods

    # Creates a DLibrary instance.
    #
    def initialize
      # Create instance hashes used for dictionary data and method conversion:
      @elements = Hash.new
      @uids = Hash.new
      @methods_from_names = Hash.new
      @names_from_methods = Hash.new
      # Load the elements dictionary:
      File.open('dictionary/elements.txt').each do |record|
        fields = record.split("\t")
        # Store the elements in a hash with tag as key and the element instance as value:
        element = DictionaryElement.new(fields[0], fields[1], fields[2].split(","), fields[3].rstrip, fields[4].rstrip)
        @elements[fields[0]] = element
        # Populate the method conversion hashes with element data:
        method = element.name.to_element_method
        @methods_from_names[element.name] = method
        @names_from_methods[method] = element.name
       end
      # Load the unique identifiers dictionary:
      File.open('dictionary/uids.txt').each do |record|
        fields = record.split("\t")
        # Store the uids in a hash with uid-value as key and the uid instance as value:
        @uids[fields[0]] = UID.new(fields[0], fields[1], fields[2].rstrip, fields[3].rstrip)
       end
    end

    # Returns the method (symbol) corresponding to the specified string value
    # (which may represent a element tag, name or method).
    # Returns nil if no match is found.
    #
    def as_method(value)
      case true
      when value.tag?
        @methods_from_names[element(value).name]
      when value.dicom_name?
        @methods_from_names[value]
      when value.dicom_method?
        @names_from_methods.has_key?(value.to_sym) ? value.to_sym : nil
      else
        nil
      end
    end

    # Returns the name (string) corresponding to the specified string value
    # (which may represent an element tag, name or method).
    # Returns nil if no match is found.
    #
    def as_name(value)
      case true
      when value.tag?
        element(value).name
      when value.dicom_name?
        @methods_from_names.has_key?(value) ? value.to_s : nil
      when value.dicom_method?
        @names_from_methods[value.to_sym]
      else
        nil
      end
    end

    # Returns the tag (string) corresponding to the specified string value
    # (which may represent a element tag, name or method).
    # Returns nil if no match is found.
    #
    def as_tag(value)
      case true
      when value.tag?
        element(value) ? value : nil
      when value.dicom_name?
        get_tag(value)
      when value.dicom_method?
        get_tag(@names_from_methods[value.to_sym])
      else
        nil
      end
    end

    # Identifies the DictionaryElement that corresponds to the given tag.
    #
    # @note If a given tag doesn't return a dictionary match, a new DictionaryElement is created.
    #   For private tags, a name 'Private' and VR 'UN' is assigned.
    #   For unknown tags, a name 'Unknown' and VR 'UN' is assigned.
    # @param [String] tag The tag of the element.
    # @return [DictionaryElement] A corresponding DictionaryElement.
    #
    def element(tag)
      element = @elements[tag]
      unless element
        if tag.group_length?
          element = DictionaryElement.new(tag, 'Group Length', ['UL'], '1', '')
        else
          if tag.private?
            element = DictionaryElement.new(tag, 'Private', ['UN'], '1', '')
          else
            if !(de = @elements["#{tag[0..3]},xxx#{tag[8]}"]).nil? # 1000,xxxh
              element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
            elsif !(de = @elements["#{tag[0..3]},xxxx"]).nil? # 1010,xxxx
              element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
            elsif !(de = @elements["#{tag[0..1]}xx,#{tag[5..8]}"]).nil? # hhxx,hhhh
              element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
            elsif !(de = @elements["#{tag[0..6]}x#{tag[8]}"]).nil? # 0028,hhxh
              element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
            else
              # We are facing an unknown (but not private) tag:
              element = DictionaryElement.new(tag, 'Unknown', ['UN'], '1', '')
            end
          end
        end
      end
      return element
    end

    # Extracts, and returns, all transfer syntaxes and SOP Classes from the dictionary,
    # in the form of a transfer syntax hash and a sop class hash.
    #
    # Both hashes have UIDs as keys and their descriptions as values.
    #
    def extract_transfer_syntaxes_and_sop_classes
      transfer_syntaxes = Hash.new
      sop_classes = Hash.new
      @uids.each_value do |uid|
        if uid.transfer_syntax?
          transfer_syntaxes[uid.value] = uid.name
        elsif uid.sop_class?
          sop_classes[uid.value] = uid.name
        end
      end
      return transfer_syntaxes, sop_classes
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
      @elements.each_value do |element|
        next unless element.name.downcase == name
        tag = element.tag
        break
      end
      @tag_name_pairs_cache[name]=tag
      return tag
    end

    # Determines, and returns, the name and vr of the data element which the specified tag belongs to.
    # Values are retrieved from the element dictionary if a match is found.
    #
    # === Notes
    #
    # * Private tags will have their names listed as 'Private'.
    # * Non-private tags that are not found in the dictionary will be listed as 'Unknown'.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
    #
    def name_and_vr(tag)
      de = element(tag)
      return de.name, de.vr
    end

    # Identifies the UID that corresponds to the given value.
    #
    # @param [String] value The unique identifier value.
    # @return [UID, NilClass] A corresponding UID instance, or nil.
    #
    def uid(value)
      @uids[value]
    end

  end
end