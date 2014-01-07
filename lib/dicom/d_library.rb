module DICOM

  # The DLibrary class contains methods for interacting with ruby-dicom's dictionary data.
  #
  # In practice, the library is for internal use and not accessed by the user. However, a
  # a library instance is available through the DICOM::LIBRARY constant.
  #
  # @example Get a dictionary element corresponding to the given tag
  #   element = DICOM::LIBRARY.element('0010,0010')
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
      add_element_dictionary("#{ROOT_DIR}/dictionary/elements.tsv")
      # Load the unique identifiers dictionary:
      add_uid_dictionary("#{ROOT_DIR}/dictionary/uids.tsv")
    end

    # Adds a custom DictionaryElement to the ruby-dicom element dictionary.
    #
    # @param [DictionaryElement] element the custom dictionary element to be added
    #
    def add_element(element)
      raise ArgumentError, "Invalid argument 'element'. Expected DictionaryElement, got #{element.class}" unless element.is_a?(DictionaryElement)
      # We store the elements in a hash with tag as key and the element instance as value:
      @elements[element.tag] = element
      # Populate the method conversion hashes with element data:
      method = element.name.to_element_method
      @methods_from_names[element.name] = method
      @names_from_methods[method] = element.name
    end

    # Adds a custom dictionary file to the ruby-dicom element dictionary.
    #
    # @note The format of the dictionary is a tab-separated text file with 5 columns:
    #   * Tag, Name, VR, VM & Retired status
    #   * For samples check out ruby-dicom's element dictionaries in the git repository
    # @param [String] file the path to the dictionary file to be added
    #
    def add_element_dictionary(file)
      File.open(file, :encoding => 'utf-8').each do |record|
        fields = record.split("\t")
        add_element(DictionaryElement.new(fields[0], fields[1], fields[2].split(","), fields[3].rstrip, fields[4].rstrip))
      end
    end

    # Adds a custom uid (e.g. SOP Class, Transfer Syntax) to the ruby-dicom uid dictionary.
    #
    # @param [UID] uid the custom uid instance to be added
    #
    def add_uid(uid)
      raise ArgumentError, "Invalid argument 'uid'. Expected UID, got #{uid.class}" unless uid.is_a?(UID)
      # We store the uids in a hash with uid-value as key and the uid instance as value:
      @uids[uid.value] = uid
    end

    # Adds a custom dictionary file to the ruby-dicom uid dictionary.
    #
    # @note The format of the dictionary is a tab-separated text file with 4 columns:
    #   * Value, Name, Type & Retired status
    #   * For samples check out ruby-dicom's uid dictionaries in the git repository
    # @param [String] file the path to the dictionary file to be added
    #
    def add_uid_dictionary(file)
      File.open(file, :encoding => 'utf-8').each do |record|
        fields = record.split("\t")
        add_uid(UID.new(fields[0], fields[1], fields[2].rstrip, fields[3].rstrip))
      end
    end


    # Gives the method (symbol) corresponding to the specified element string value.
    #
    # @param [String] value an element tag, element name or an element's method name
    # @return [Symbol, NilClass] the matched element method, or nil if no match is made
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

    # Gives the name corresponding to the specified element string value.
    #
    # @param [String] value an element tag, element name or an element's method name
    # @return [String, NilClass] the matched element name, or nil if no match is made
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

    # Gives the tag corresponding to the specified element string value.
    #
    # @param [String] value an element tag, element name or an element's method name
    # @return [String, NilClass] the matched element tag, or nil if no match is made
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
    #   * For private tags, a name 'Private' and VR 'UN' is assigned
    #   * For unknown tags, a name 'Unknown' and VR 'UN' is assigned
    # @param [String] tag the tag of the element
    # @return [DictionaryElement] a corresponding DictionaryElement
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
            element = unknown_or_range_element(tag)
          end
        end
      end
      element
    end

    # Extracts, and returns, all transfer syntaxes and SOP Classes from the dictionary.
    #
    # @return [Array<Hash, Hash>] transfer syntax and sop class hashes, each with uid as key and name as value
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

    # Gives the tag that matches the supplied data element name, by searching the element dictionary.
    #
    # @param [String] name a data element name
    # @return [String, NilClass] the corresponding element tag, or nil if no match is made
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

    # Determines the name and vr of the element which the specified tag belongs to,
    # based on a lookup in the element data dictionary.
    #
    # @note If a given tag doesn't return a dictionary match, the following values are assigned:
    #   * For private tags: name 'Private' and VR 'UN'
    #   * For unknown (non-private) tags: name 'Unknown' and VR 'UN'
    # @param [String] tag an element's tag
    # @return [Array<String, String>] the name and value representation corresponding to the given tag
    #
    def name_and_vr(tag)
      de = element(tag)
      return de.name, de.vr
    end

    # Identifies the UID that corresponds to the given value.
    #
    # @param [String] value the unique identifier value
    # @return [UID, NilClass] a corresponding UID instance, or nil (if no match is made)
    #
    def uid(value)
      @uids[value]
    end


    private


    # Creates a list of possible 'range' tag candidates based on the given tag.
    # Usually tags are uniquely defined in the DICOM dictionary, and the given
    # tag can be matched directly. However, for a small set of known tags, the
    # dictionary allows a range of tags to be associated with a specific
    # entry. This method creates an array of candidate tags which are processed
    # in order to match against these ranges.
    #
    # @param [String] tag the element tag
    # @return [Array<String>] processed candidate tags
    #
    def range_candidates(tag)
      [
        "#{tag[0..3]},xxx#{tag[8]}", # 1000,xxxh
        "#{tag[0..3]},xxxx", # 1010,xxxx
        "#{tag[0..1]}xx,#{tag[5..8]}", # hhxx,hhhh
        "#{tag[0..6]}x#{tag[8]}" # 0028,hhxh
      ]
    end

    # Matches a tag against the possible range tag candidates, and if no match
    # is found, returns a dictionary element representing an unknown tag.
    #
    # @param [String] tag the element tag
    # @return [DictionaryElement] a matched range element or an unknown element
    #
    def unknown_or_range_element(tag)
      element = nil
      range_candidates(tag).each do |range_candidate_tag|
        if de = @elements[range_candidate_tag]
          element = DictionaryElement.new(tag, de.name, de.vrs, de.vm, de.retired)
          break
        end
      end
      # If nothing was matched, we are facing an unknown (but not private) tag:
      element ||= DictionaryElement.new(tag, 'Unknown', ['UN'], '1', '')
    end

  end

end
