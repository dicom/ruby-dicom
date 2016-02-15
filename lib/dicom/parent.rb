module DICOM

  # Super class which contains common code for all parent elements.
  #
  # === Inheritance
  #
  # Since all parents inherit from this class, these methods are available to instances of the following classes:
  # * DObject
  # * Item
  # * Sequence
  #
  class Parent

    include Logging

    # Retrieves the child element matching the specified element tag or item index.
    #
    # Only immediate children are searched. Grandchildren etc. are not included.
    #
    # @param [String, Integer] tag_or_index a ruby-dicom tag string or item index
    # @return [Element, Sequence, Item, NilClass] the matched element (or nil, if no match was made)
    # @example Extract the "Pixel Data" data element from the DObject instance
    #   pixel_data_element = dcm["7FE0,0010"]
    # @example Extract the first Item from a Sequence
    #   first_item = dcm["3006,0020"][0]
    #
    def [](tag_or_index)
      formatted = tag_or_index.is_a?(String) ? tag_or_index.upcase : tag_or_index
      return @tags[formatted]
    end

    # Adds an Element or Sequence instance to self (where self can be either a DObject or an Item).
    #
    # @note Items can not be added with this method (use add_item instead).
    #
    # @param [Element, Sequence] element a child element/sequence
    # @param [Hash] options the options used for adding the element/sequence
    # option options [Boolean] :no_follow when true, the method does not update the parent attribute of the child that is added
    # @example Set a new patient's name to the DICOM object
    #   dcm.add(Element.new("0010,0010", "John_Doe"))
    # @example Add a previously defined element roi_name to the first item of a sequence
    #   dcm["3006,0020"][0].add(roi_name)
    #
    def add(element, options={})
      unless element.is_a?(Item)
        unless self.is_a?(Sequence)
          # Does the element's binary value need to be reencoded?
          reencode = true if element.is_a?(Element) && element.endian != stream.str_endian
          # If we are replacing an existing Element, we need to make sure that this Element's parent value is erased before proceeding.
          self[element.tag].parent = nil if exists?(element.tag)
          # Add the element, and set its parent attribute:
          @tags[element.tag] = element
          element.parent = self unless options[:no_follow]
          # As the element has been moved in place, perform re-encode if indicated:
          element.value = element.value if reencode
        else
          raise "A Sequence is only allowed to have Item elements added to it. Use add_item() instead if the intention is to add an Item."
        end
      else
        raise ArgumentError, "An Item is not allowed as a parameter to the add() method. Use add_item() instead."
      end
    end

    # Retrieves all (immediate) child elementals in an array (sorted by element tag).
    #
    # @return [Array<Element, Item, Sequence>] the parent's child elementals (an empty array if childless)
    # @example Retrieve all top level elements in a DICOM object
    #   top_level_elements = dcm.children
    #
    def children
      return @tags.sort.transpose[1] || Array.new
    end

    # Checks if an element actually has any child elementals (elements/items/sequences).
    #
    # Notice the subtle difference between the children? and is_parent? methods. While they
    # will give the same result in most real use cases, they differ when used on parent elements
    # that do not have any children added yet.
    #
    # For example, when called on an empty Sequence, the children? method
    # will return false, whereas the is_parent? method still returns true.
    #
    # @return [Boolean] true if the element has children, and false if not
    #
    def children?
      if @tags.length > 0
        return true
      else
        return false
      end
    end

    # Gives the number of elements connected directly to this parent.
    #
    # This count does NOT include the number of elements contained in any possible child elements.
    #
    # @return [Integer] The number of child elements belonging to this parent
    #
    def count
      return @tags.length
    end

    # Gives the total number of elements connected to this parent.
    #
    # This count includes all the elements contained in any possible child elements.
    #
    # @return [Integer] The total number of child elements connected to this parent
    #
    def count_all
      # Iterate over all elements, and repeat recursively for all elements which themselves contain children.
      total_count = count
      @tags.each_value do |value|
        total_count += value.count_all if value.children?
      end
      return total_count
    end

    # Deletes the specified element from this parent.
    #
    # @param [String, Integer] tag_or_index a ruby-dicom tag string or item index
    # @param [Hash] options the options used for deleting the element
    # option options [Boolean] :no_follow when true, the method does not update the parent attribute of the child that is deleted
    # @example Delete an Element from a DObject instance
    #   dcm.delete("0008,0090")
    # @example Delete Item 1 from a Sequence
    #   dcm["3006,0020"].delete(1)
    #
    def delete(tag_or_index, options={})
      check_key(tag_or_index, :delete)
      # We need to delete the specified child element's parent reference in addition to removing it from the tag Hash.
      element = self[tag_or_index]
      if element
        element.parent = nil unless options[:no_follow]
        @tags.delete(tag_or_index)
      end
    end

    # Deletes all child elements from this parent.
    #
    def delete_children
      @tags.each_key do |tag|
        delete(tag)
      end
    end

    # Deletes all elements of the specified group from this parent.
    #
    # @param [String] group_string a group string (the first 4 characters of a tag string)
    # @example Delete the File Meta Group of a DICOM object
    #   dcm.delete_group("0002")
    #
    def delete_group(group_string)
      group_elements = group(group_string)
      group_elements.each do |element|
        delete(element.tag)
      end
    end

    # Deletes all private data/sequence elements from this parent.
    #
    # @example Delete all private elements from a DObject instance
    #   dcm.delete_private
    # @example Delete only private elements belonging to a specific Sequence
    #   dcm["3006,0020"].delete_private
    #
    def delete_private
      # Iterate all children, and repeat recursively if a child itself has children, to delete all private data elements:
      children.each do |element|
        delete(element.tag) if element.tag.private?
        element.delete_private if element.children?
      end
    end

    # Deletes all retired data/sequence elements from this parent.
    #
    # @example Delete all retired elements from a DObject instance
    #   dcm.delete_retired
    #
    def delete_retired
      # Iterate all children, and repeat recursively if a child itself has children, to delete all retired elements:
      children.each do |element|
        dict_element = LIBRARY.element(element.tag)
        delete(element.tag) if dict_element && dict_element.retired?
        element.delete_retired if element.children?
      end
    end

    # Iterates all children of this parent, calling <tt>block</tt> for each child.
    #
    def each(&block)
      children.each_with_index(&block)
    end

    # Iterates the child elements of this parent, calling <tt>block</tt> for each element.
    #
    def each_element(&block)
      elements.each_with_index(&block) if children?
    end

    # Iterates the child items of this parent, calling <tt>block</tt> for each item.
    #
    def each_item(&block)
      items.each_with_index(&block) if children?
    end

    # Iterates the child sequences of this parent, calling <tt>block</tt> for each sequence.
    #
    def each_sequence(&block)
      sequences.each_with_index(&block) if children?
    end

    # Iterates the child tags of this parent, calling <tt>block</tt> for each tag.
    #
    def each_tag(&block)
      @tags.each_key(&block)
    end

    # Retrieves all child elements of this parent in an array.
    #
    # @return [Array<Element>] child elements (or empty array, if childless)
    #
    def elements
      children.select { |child| child.is_a?(Element)}
    end

    # A boolean which indicates whether the parent has any child elements.
    #
    # @return [Boolean] true if any child elements exists, and false if not
    #
    def elements?
      elements.any?
    end

    # Re-encodes the binary data strings of all child Element instances.
    # This also includes all the elements contained in any possible child elements.
    #
    # @note This method is only intended for internal library use, but for technical reasons
    #   (the fact that is called between instances of different classes), can't be made private.
    # @param [Boolean] old_endian the previous endianness of the elements/DObject instance (used for decoding values from binary)
    #
    def encode_children(old_endian)
       # Cycle through all levels of children recursively:
      children.each do |element|
        if element.children?
          element.encode_children(old_endian)
        elsif element.is_a?(Element)
          encode_child(element, old_endian)
        end
      end
    end

    # Checks whether a specific data element tag is defined for this parent.
    #
    # @param [String, Integer] tag_or_index a ruby-dicom tag string or item index
    # @return [Boolean] true if the element is found, and false if not
    # @example Do something with an element only if it exists
    #   process_name(dcm["0010,0010"]) if dcm.exists?("0010,0010")
    #
    def exists?(tag_or_index)
      if self[tag_or_index]
        return true
      else
        return false
      end
    end

    # Returns an array of all child elements that belongs to the specified group.
    #
    # @param [String] group_string a group string (the first 4 characters of a tag string)
    # @return [Array<Element, Item, Sequence>] the matching child elements (an empty array if no children matches)
    #
    def group(group_string)
      raise ArgumentError, "Expected String, got #{group_string.class}." unless group_string.is_a?(String)
      found = Array.new
      children.each do |child|
        found << child if child.tag.group == group_string.upcase
      end
      return found
    end

    # Gathers the desired information from the selected data elements and
    # processes this information to make a text output which is nicely formatted.
    #
    # @note This method is only intended for internal library use, but for technical reasons
    #   (the fact that is called between instances of different classes), can't be made private.
    #   The method is used by the print() method to construct its text output.
    #
    # @param [Integer] index the index which is given to the first child of this parent
    # @param [Integer] max_digits the maximum number of digits in the index of an element (in reality the number of digits of the last element)
    # @param [Integer] max_name the maximum number of characters in the name of any element to be printed
    # @param [Integer] max_length the maximum number of digits in the length of an element
    # @param [Integer] max_generations the maximum number of generations of children for this parent
    # @param [Integer] visualization an array of string symbols which visualizes the tree structure that the children of this particular parent belongs to (for no visualization, an empty array is passed)
    # @param [Hash] options the options to use when processing the print information
    # @option options [Integer] :value_max if a value max length is specified, the element values which exceeds this are trimmed
    # @return [Array] a text array and an index of the last element
    #
    def handle_print(index, max_digits, max_name, max_length, max_generations, visualization, options={})
      # FIXME: This method is somewhat complex, and some simplification, if possible, wouldn't hurt.
      elements = Array.new
      s = " "
      hook_symbol = "|_"
      last_item_symbol = "  "
      nonlast_item_symbol = "| "
      children.each_with_index do |element, i|
        n_parents = element.parents.length
        # Formatting: Index
        i_s = s*(max_digits-(index).to_s.length)
        # Formatting: Name (and Tag)
        if element.tag == ITEM_TAG
          # Add index numbers to the Item names:
          name = "#{element.name} (\##{i})"
        else
          name = element.name
        end
        n_s = s*(max_name-name.length)
        # Formatting: Tag
        tag = "#{visualization.join}#{element.tag}"
        t_s = s*((max_generations-1)*2+9-tag.length)
        # Formatting: Length
        l_s = s*(max_length-element.length.to_s.length)
        # Formatting Value:
        if element.is_a?(Element)
          value = element.value.to_s
        else
          value = ""
        end
        if options[:value_max]
          value = "#{value[0..(options[:value_max]-3)]}.." if value.length > options[:value_max]
        end
        elements << "#{i_s}#{index} #{tag}#{t_s} #{name}#{n_s} #{element.vr} #{l_s}#{element.length} #{value}"
        index += 1
        # If we have child elements, print those elements recursively:
        if element.children?
          if n_parents > 1
            child_visualization = Array.new
            child_visualization.replace(visualization)
            if element == children.first
              if children.length == 1
                # Last item:
                child_visualization.insert(n_parents-2, last_item_symbol)
              else
                # More items follows:
                child_visualization.insert(n_parents-2, nonlast_item_symbol)
              end
            elsif element == children.last
              # Last item:
              child_visualization[n_parents-2] = last_item_symbol
              child_visualization.insert(-1, hook_symbol)
            else
              # Neither first nor last (more items follows):
              child_visualization.insert(n_parents-2, nonlast_item_symbol)
            end
          elsif n_parents == 1
            child_visualization = Array.new(1, hook_symbol)
          else
            child_visualization = Array.new
          end
          new_elements, index = element.handle_print(index, max_digits, max_name, max_length, max_generations, child_visualization, options)
          elements << new_elements
        end
      end
      return elements.flatten, index
    end

    # Gives a string containing a human-readable hash representation of the parent.
    #
    # @return [String] a hash representation string of the parent
    #
    def inspect
      to_hash.inspect
    end

    # Checks if an elemental is a parent.
    #
    # @return [Boolean] true for all parent elementals (Item, Sequence, DObject)
    #
    def is_parent?
      return true
    end

    # Retrieves all child items of this parent in an array.
    #
    # @return [Array<Item>] child items (or empty array, if childless)
    #
    def items
      children.select { |child| child.is_a?(Item)}
    end

    # A boolean which indicates whether the parent has any child items.
    #
    # @return [Boolean] true if any child items exists, and false if not
    #
    def items?
      items.any?
    end

    # Sets the length of a Sequence or Item.
    #
    # @note Currently, ruby-dicom does not use sequence/item lengths when writing DICOM files
    # (it sets the length to -1, meaning UNDEFINED). Therefore, in practice, it isn't
    # necessary to use this method, at least as far as writing (valid) DICOM files is concerned.
    #
    # @param [Integer] new_length the new length to assign to the Sequence/Item
    #
    def length=(new_length)
      unless self.is_a?(DObject)
        @length = new_length
      else
        raise "Length can not be set for a DObject instance."
      end
    end

    # Finds and returns the maximum character lengths of name and length which occurs for any child element,
    # as well as the maximum number of generations of elements.
    #
    # @note This method is only intended for internal library use, but for technical reasons
    #   (the fact that is called between instances of different classes), can't be made private.
    #   The method is used by the print() method to achieve a proper format in its output.
    #
    def max_lengths
      max_name = 0
      max_length = 0
      max_generations = 0
      children.each do |element|
        if element.children?
          max_nc, max_lc, max_gc = element.max_lengths
          max_name = max_nc if max_nc > max_name
          max_length = max_lc if max_lc > max_length
          max_generations = max_gc if max_gc > max_generations
        end
        n_length = element.name.length
        l_length = element.length.to_s.length
        generations = element.parents.length
        max_name = n_length if n_length > max_name
        max_length = l_length if l_length > max_length
        max_generations = generations if generations > max_generations
      end
      return max_name, max_length, max_generations
    end

    # Handles missing methods, which in our case is intended to be dynamic
    # method names matching DICOM elements in the dictionary.
    #
    # When a dynamic method name is matched against a DICOM element, this method:
    # * Returns the element if the method name suggests an element retrieval, and the element exists.
    # * Returns nil if the method name suggests an element retrieval, but the element doesn't exist.
    # * Returns a boolean, if the method name suggests a query (?), based on whether the matched element exists or not.
    # * When the method name suggests assignment (=), an element is created with the supplied arguments, or if the argument is nil, the element is deleted.
    #
    # * When a dynamic method name is not matched against a DICOM element, and the method is not defined by the parent, a NoMethodError is raised.
    #
    # @param [Symbol] sym a method name
    #
    def method_missing(sym, *args, &block)
      s = sym.to_s
      action = s[-1]
      # Try to match the method against a tag from the dictionary:
      tag = LIBRARY.as_tag(s) || LIBRARY.as_tag(s[0..-2])
      if tag
        if action == '?'
          # Query:
          return self.exists?(tag)
        elsif action == '='
          # Assignment:
          unless args.length==0 || args[0].nil?
            # What kind of element to create?
            if tag == 'FFFE,E000'
              return self.add_item
            elsif LIBRARY.element(tag).vr == 'SQ'
              return self.add(Sequence.new(tag))
            else
              return self.add(Element.new(tag, *args))
            end
          else
            return self.delete(tag)
          end
        else
          # Retrieval:
          return self[tag]
        end
      end
      # Forward to Object#method_missing:
      super
    end

    # Prints all child elementals of this particular parent.
    # Information such as tag, parent-child relationship, name, vr, length and value is
    # gathered for each element and processed to produce a nicely formatted output.
    #
    # @param [Hash] options the options to use for handling the printout
    # option options [Integer] :value_max if a value max length is specified, the element values which exceeds this are trimmed
    # option options [String] :file if a file path is specified, the output is printed to this file instead of being printed to the screen
    # @return [Array<String>] an array of formatted element string lines
    # @example Print a DObject instance to screen
    #   dcm.print
    # @example Print the DObject to the screen, but specify a 25 character value cutoff to produce better-looking results
    #   dcm.print(:value_max => 25)
    # @example Print to a text file the elements that belong to a specific Sequence
    #   dcm["3006,0020"].print(:file => "dicom.txt")
    #
    def print(options={})
      # FIXME: Perhaps a :children => false option would be a good idea (to avoid lengthy printouts in cases where this would be desirable)?
      # FIXME: Speed. The new print algorithm may seem to be slower than the old one (observed on complex, hiearchical DICOM files). Perhaps it can be optimized?
      elements = Array.new
      # We first gather some properties that is necessary to produce a nicely formatted printout (max_lengths, count_all),
      # then the actual information is gathered (handle_print),
      # and lastly, we pass this information on to the methods which print the output (print_file or print_screen).
      if count > 0
        max_name, max_length, max_generations = max_lengths
        max_digits = count_all.to_s.length
        visualization = Array.new
        elements, index = handle_print(start_index=1, max_digits, max_name, max_length, max_generations, visualization, options)
        if options[:file]
          print_file(elements, options[:file])
        else
          print_screen(elements)
        end
      else
        puts "Notice: Object #{self} is empty (contains no data elements)!"
      end
      return elements
    end

    # Gives a string which represents this DICOM parent. The DOBject is
    # is represented by its class name, whereas elemental parents (Sequence,
    # Item) is represented by their tags.
    #
    # @return [String] a representation of the DICOM parent
    #
    def representation
      self.is_a?(DObject) ? 'DObject' : self.tag
    end

    # Resets the length of a Sequence or Item to -1, which is the number used for 'undefined' length.
    #
    def reset_length
      unless self.is_a?(DObject)
        @length = -1
        @bin = ""
      else
        raise "Length can not be set for a DObject instance."
      end
    end

    # Checks if the parent responds to the given method (symbol) (whether the method is defined or not).
    #
    # @param [Symbol] method a method name who's response is tested
    # @param [Boolean] include_private if true, private methods are included in the search (not used by ruby-dicom)
    # @return [Boolean] true if the parent responds to the given method (method is defined), and false if not
    #
    def respond_to?(method, include_private=false)
      # Check the library for a tag corresponding to the given method name symbol:
      return true unless LIBRARY.as_tag(method.to_s).nil?
      # In case of a query (xxx?) or assign (xxx=), remove last character and try again:
      return true unless LIBRARY.as_tag(method.to_s[0..-2]).nil?
      # Forward to Object#respond_to?:
      super
    end

    # Retrieves all child sequences of this parent in an array.
    #
    # @return [Array<Sequence>] child sequences (or empty array, if childless)
    #
    def sequences
      children.select { |child| child.is_a?(Sequence) }
    end

    # A boolean which indicates whether the parent has any child sequences.
    #
    # @return [Boolean] true if any child sequences exists, and false if not
    #
    def sequences?
      sequences.any?
    end

    # Builds a nested hash containing all children of this parent.
    #
    # Keys are determined by the key_representation attribute, and data element values are used as values.
    # * For private elements, the tag is used for key instead of the key representation, as private tags lacks names.
    # * For child-less parents, the key_representation attribute is used as value.
    #
    # @return [Hash] a nested hash containing key & value pairs of all children
    #
    def to_hash
      as_hash = Hash.new
      unless children?
        if self.is_a?(DObject)
          as_hash = {}
        else
          as_hash[(self.tag.private?) ? self.tag : self.send(DICOM.key_representation)] = nil
        end
      else
        children.each do |child|
          if child.tag.private?
            hash_key = child.tag
          elsif child.is_a?(Item)
            hash_key = "Item #{child.index}"
          else
            hash_key = child.send(DICOM.key_representation)
          end
          if child.is_a?(Element)
            as_hash[hash_key] = child.to_hash[hash_key]
          else
            as_hash[hash_key] = child.to_hash
          end
        end
      end
      return as_hash
    end

    # Builds a json string containing a human-readable representation of the parent.
    #
    # @return [String] a human-readable representation of this parent
    #
    def to_json
      to_hash.to_json
    end

    # Returns a yaml string containing a human-readable representation of the parent.
    #
    # @return [String] a human-readable representation of this parent
    #
    def to_yaml
      to_hash.to_yaml
    end

    # Gives the value of a specific Element child of this parent.
    #
    # * Only Element instances have values. Parent elements like Sequence and Item have no value themselves.
    # * If the specified tag is that of a parent element, an exception is raised.
    #
    # @param [String] tag a tag string which identifies the child Element
    # @return [String, Integer, Float, NilClass] an element value (or nil, if no element is matched)
    # @example Get the patient's name value
    #   name = dcm.value("0010,0010")
    # @example Get the Frame of Reference UID from the first item in the Referenced Frame of Reference Sequence
    #   uid = dcm["3006,0010"][0].value("0020,0052")
    #
    def value(tag)
      check_key(tag, :value)
      if exists?(tag)
        if self[tag].is_parent?
          raise ArgumentError, "Illegal parameter '#{tag}'. Parent elements, like the referenced '#{@tags[tag].class}', have no value. Only Element tags are valid."
        else
          return self[tag].value
        end
      else
        return nil
      end
    end


    private


    # Checks the given key argument and logs a warning if an obviously
    # incorrect key argument is used.
    #
    # @param [String, Integer] tag_or_index the tag string or item index indentifying a given elemental
    # @param [Symbol] method a representation of the method calling this method
    #
    def check_key(tag_or_index, method)
      if tag_or_index.is_a?(String)
        logger.warn("Parent##{method} called with an invalid tag argument: #{tag_or_index}") unless tag_or_index.tag?
      elsif tag_or_index.is_a?(Integer)
        logger.warn("Parent##{method} called with a negative Integer argument: #{tag_or_index}") if tag_or_index < 0
      else
        logger.warn("Parent##{method} called with an unexpected argument. Expected String or Integer, got: #{tag_or_index.class}")
      end
    end

    # Re-encodes the value of a child Element (but only if the
    # Element encoding is influenced by a shift in endianness).
    #
    # @param [Element] element the Element who's value will be re-encoded
    # @param [Boolean] old_endian the previous endianness of the element binary (used for decoding the value)
    #
    def encode_child(element, old_endian)
      if element.tag == "7FE0,0010"
        # As encoding settings of the DObject has already been changed, we need to decode the old pixel values with the old encoding:
        stream_old_endian = Stream.new(nil, old_endian)
        pixels = decode_pixels(element.bin, stream_old_endian)
        encode_pixels(pixels, stream)
      else
        # Not all types of tags needs to be reencoded when switching endianness:
        case element.vr
          when "US", "SS", "UL", "SL", "FL", "FD", "OF", "OW", "AT" # Numbers or tag reference
            # Re-encode, as long as it is not a group 0002 element (which must always be little endian):
            unless element.tag.group == "0002"
              stream_old_endian = Stream.new(element.bin, old_endian)
              formatted_value = stream_old_endian.decode(element.length, element.vr)
              element.value = formatted_value # (the value=() method also encodes a new binary for the element)
            end
        end
      end
    end

    # Initializes common variables among the parent elements.
    #
    def initialize_parent
      # All child data elements and sequences are stored in a hash where the tag string is used as key:
      @tags = Hash.new
    end

    # Prints an array of formatted element string lines gathered by the print() method to file.
    #
    # @param [Array<String>] elements an array of formatted element string lines
    # @param [String] file a path/file_name string
    #
    def print_file(elements, file)
      File.open(file, 'w') do |output|
        elements.each do |line|
          output.print line + "\n"
        end
      end
    end

    # Prints an array of formatted element string lines gathered by the print() method to the screen.
    #
    # @param [Array<String>] elements an array of formatted element string lines
    #
    def print_screen(elements)
      elements.each do |line|
        puts line
      end
    end

  end
end
