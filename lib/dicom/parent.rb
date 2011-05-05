#    Copyright 2008-2011 Christoffer Lervag

module DICOM

  # Super class which contains common code for all parent elements.
  #
  # === Inheritance
  #
  # Since all parent elements inherit from this class, these methods are available to instances of the following classes:
  # * DObject
  # * Item
  # * Sequence
  #
  class SuperParent

    # Returns the specified child element.
    # If the requested data element isn't found, nil is returned.
    #
    # === Notes
    #
    # * Only immediate children are searched. Grandchildren etc. are not included.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A tag string which identifies the data element to be returned (Exception: In the case where an Item is wanted, an index (Fixnum) is used instead).
    #
    # === Examples
    #
    #   # Extract the "Pixel Data" data element from the DObject instance:
    #   pixel_data_element = obj["7FE0,0010"]
    #   # Extract the first Item from a Sequence:
    #   first_item = obj["3006,0020"][1]
    #
    def [](tag)
      return @tags[tag]
    end

    # Adds a DataElement or Sequence instance to self (where self can be either a DObject or an Item).
    #
    # === Restrictions
    #
    # * Items can not be added with this method.
    #
    # === Parameters
    #
    # * <tt>element</tt> -- An element (DataElement or Sequence).
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:no_follow</tt> -- Boolean. If true, the method does not update the parent attribute of the child that is added.
    #
    # === Examples
    #
    #   # Set a new patient's name to the DICOM object:
    #   obj.add(DataElement.new("0010,0010", "John_Doe"))
    #   # Add a previously defined element roi_name to the first item in the following sequence:
    #   obj["3006,0020"][0].add(roi_name)
    #
    def add(element, options={})
      unless element.is_a?(Item)
        unless self.is_a?(Sequence)
          # Does the element's binary value need to be reencoded?
          reencode = true if element.is_a?(DataElement) && element.endian != stream.str_endian
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

    # Adds a child item to a Sequence (or Item in some cases where pixel data is encapsulated).
    # If no existing Item is specified, an empty item will be added.
    #
    # === Notes
    #
    # * Items are specified by index (starting at 0) instead of a tag string!
    #
    # === Parameters
    #
    # * <tt>item</tt> -- The Item instance that is to be added (defaults to nil, in which case an empty Item will be added).
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:index</tt> -- Fixnum. If the Item is to be inserted at a specific index (Item number), this option parameter needs to set.
    # * <tt>:no_follow</tt> -- Boolean. If true, the method does not update the parent attribute of the child that is added.
    #
    # === Examples
    #
    #   # Add an empty Item to a specific Sequence:
    #   obj["3006,0020"].add_item
    #   # Add an existing Item at the 2nd item position/index in the specific Sequence:
    #   obj["3006,0020"].add_item(my_item, :index => 2)
    #
    def add_item(item=nil, options={})
      unless self.is_a?(DObject)
        if item
          if item.is_a?(Item)
            if options[:index]
              # This Item will take a specific index, and all existing Items with index higher or equal to this number will have their index increased by one.
              # Check if index is valid (must be an existing index):
              if options[:index] >= 0
                # If the index value is larger than the max index present, we dont need to modify the existing items.
                if options[:index] < @tags.length
                  # Extract existing Hash entries to an array:
                  pairs = @tags.sort
                  @tags = Hash.new
                  # Change the key of those equal or larger than index and put these key,value pairs back in a new Hash:
                  pairs.each do |pair|
                    if pair[0] < options[:index]
                      @tags[pair[0]] = pair[1] # (Item keeps its old index)
                    else
                      @tags[pair[0]+1] = pair[1]
                      pair[1].index = pair[0]+1 # (Item gets updated with its new index)
                    end
                  end
                else
                  # Set the index value one higher than the already existing max value:
                  options[:index] = @tags.length
                end
                #,Add the new Item and set its index:
                @tags[options[:index]] = item
                item.index = options[:index]
              else
                raise ArgumentError, "The specified index (#{options[:index]}) is out of range (Must be a positive integer)."
              end
            else
              # Add the existing Item to this Sequence:
              index = @tags.length
              @tags[index] = item
              # Let the Item know what index key it's got in it's parent's Hash:
              item.index = index
            end
            # Set ourself as this item's new parent:
            item.set_parent(self) unless options[:no_follow]
          else
            raise ArgumentError, "The specified parameter is not an Item. Only Items are allowed to be added to a Sequence."
          end
        else
          # Create an empty Item with self as parent.
          index = @tags.length
          item = Item.new(:parent => self)
        end
      else
        raise "An Item #{item} was attempted added to a DObject instance #{self}, which is not allowed."
      end
    end

    # Returns all (immediate) child elements in an array (sorted by element tag).
    # If this particular parent doesn't have any children, an empty array is returned
    #
    # === Examples
    #
    #   # Retrieve all top level data elements in a DICOM object:
    #   top_level_elements = obj.children
    #
    def children
      return @tags.sort.transpose[1] || Array.new
    end

    # Checks if an element actually has any child elements.
    # Returns true if it has and false if it doesn't.
    #
    # === Notes
    #
    # Notice the subtle difference between the children? and is_parent? methods. While they
    # will give the same result in most real use cases, they differ when used on parent elements
    # that do not have any children added yet.
    #
    # For example, when called on an empty Sequence, the children? method will return false,
    # while the is_parent? method still returns true.
    #
    def children?
      if @tags.length > 0
        return true
      else
        return false
      end
    end

    # Counts and returns the number of elements contained directly in this parent.
    # This count does NOT include the number of elements contained in any possible child elements.
    #
    def count
      return @tags.length
    end

    # Counts and returns the total number of elements contained in this parent.
    # This count includes all the elements contained in any possible child elements.
    #
    def count_all
      # Iterate over all elements, and repeat recursively for all elements which themselves contain children.
      total_count = count
      @tags.each_value do |value|
        total_count += value.count_all if value.children?
      end
      return total_count
    end

    # Iterates the children of this parent, calling <tt>block</tt> for each child.
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

    # Returns all child elements of this parent in an array.
    # If no child elements exists, returns an empty array.
    #
    def elements
      children.select { |child| child.is_a?(DataElement)}
    end

    # A boolean which indicates whether the parent has any child elements.
    #
    def elements?
      elements.any?
    end

    # Re-encodes the binary data strings of all child DataElement instances.
    # This also includes all the elements contained in any possible child elements.
    #
    # === Notes
    #
    # This method is not intended for external use, but for technical reasons (the fact that is called between
    # instances of different classes), cannot be made private.
    #
    # === Parameters
    #
    # * <tt>old_endian</tt> -- The previous endianness of the elements/DObject instance (used for decoding values from binary).
    #
    def encode_children(old_endian)
       # Cycle through all levels of children recursively:
      children.each do |element|
        if element.children?
          element.encode_children(old_endian)
        elsif element.is_a?(DataElement)
          encode_child(element, old_endian)
        end
      end
    end

    # Checks whether a specific data element tag is defined for this parent.
    # Returns true if the tag is found and false if not.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A tag string which identifies the data element that is queried (Exception: In the case of an Item query, an index integer is used instead).
    #
    # === Examples
    #
    #   process_name(obj["0010,0010"]) if obj.exists?("0010,0010")
    #
    def exists?(tag)
      if @tags[tag]
        return true
      else
        return false
      end
    end

    # Returns an array of all child elements that belongs to the specified group.
    # If no matches are found, returns an empty array.
    #
    # === Parameters
    #
    # * <tt>group_string</tt> -- A group string (the first 4 characters of a tag string).
    #
    def group(group_string)
      raise ArgumentError, "Expected String, got #{group_string.class}." unless group_string.is_a?(String)
      found = Array.new
      children.each do |child|
        found << child if child.tag.group == group_string
      end
      return found
    end

    # Gathers the desired information from the selected data elements and processes this information to make
    # a text output which is nicely formatted. Returns a text array and an index of the last data element.
    #
    # === Notes
    #
    # This method is not intended for external use, but for technical reasons (the fact that is called between
    # instances of different classes), cannot be made private.
    #
    # The method is used by the print() method to construct the text output.
    #
    # === Parameters
    #
    # * <tt>index</tt> -- Fixnum. The index which is given to the first child of this parent.
    # * <tt>max_digits</tt> -- Fixnum. The maximum number of digits in the index of an element (which is the index of the last element).
    # * <tt>max_name</tt> -- Fixnum. The maximum number of characters in the name of any element to be printed.
    # * <tt>max_length</tt> -- Fixnum. The maximum number of digits in the length of an element.
    # * <tt>max_generations</tt> -- Fixnum. The maximum number of generations of children for this parent.
    # * <tt>visualization</tt> -- An array of string symbols which visualizes the tree structure that the children of this particular parent belongs to. For no visualization, an empty array is passed.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:value_max</tt> -- Fixnum. If a value max length is specified, the data elements who's value exceeds this length will be trimmed to this length.
    #
    #--
    # FIXME: This method is somewhat complex, and some simplification, if possible, wouldn't hurt.
    #
    def handle_print(index, max_digits, max_name, max_length, max_generations, visualization, options={})
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
        if element.is_a?(DataElement)
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

    # Returns a string containing a human-readable hash representation of the element.
    #
    def inspect
      to_hash.inspect
    end

    # Checks if an element is a parent.
    # Returns true for all parent elements.
    #
    def is_parent?
      return true
    end

    # Returns all child items of this parent in an array.
    # If no child items exists, returns an empty array.
    #
    def items
      children.select { |child| child.is_a?(Item)}
    end

    # A boolean which indicates whether the parent has any child items.
    #
    def items?
      items.any?
    end

    # Handles missing methods, which in our case is intended to be dynamic
    # method names matching DICOM elements in the dictionary.
    #
    # === Notes
    #
    # * When a dynamic method name is matched against a DICOM element, this method:
    # * Returns the element if the method name suggests an element retrieval, and the element exists.
    # * Returns nil if the method name suggests an element retrieval, but the element doesn't exist.
    # * Returns a boolean, if the method name suggests a query (?), based on whether the matched element exists or not.
    # * When the method name suggests assignment (=), an element is created with the supplied arguments, or if the argument is nil, the element is removed.
    #
    # * When a dynamic method name is not matched against a DICOM element, and the method is not defined by the parent, a NoMethodError is raised.
    #
    # === Parameters
    #
    # * <tt>sym</tt> -- Symbol. A method name.
    #
    def method_missing(sym, *args, &block)
      # Try to match the method against a tag from the dictionary:
      tag = LIBRARY.as_tag(sym.to_s) || LIBRARY.as_tag(sym.to_s[0..-2])
      if tag
        if sym.to_s[-1..-1] == '?'
          # Query:
          return self.exists?(tag)
        elsif sym.to_s[-1..-1] == '='
          # Assignment:
          unless args.length==0 || args[0].nil?
            # What kind of element to create?
            if tag == "FFFE,E000"
              return self.add_item
            elsif LIBRARY.tags[tag][0][0] == "SQ"
              return self.add(Sequence.new(tag))
            else
              return self.add(DataElement.new(tag, *args))
            end
          else
            return self.remove(tag)
          end
        else
          # Retrieval:
          return self[tag] rescue nil
        end
      end
      # Forward to Object#method_missing:
      super
    end

    # Sets the length of a Sequence or Item.
    #
    # === Notes
    #
    # Currently, Ruby DICOM does not use sequence/item lengths when writing DICOM files
    # (it sets the length to -1, which means UNDEFINED). Therefore, in practice, it isn't
    # necessary to use this method, at least as far as writing (valid) DICOM files is concerned.
    #
    # === Parameters
    #
    # * <tt>new_length</tt> -- Fixnum. The new length to assign to the Sequence/Item.
    #
    def length=(new_length)
      unless self.is_a?(DObject)
        @length = new_length
      else
        raise "Length can not be set for a DObject instance."
      end
    end

    # Prints all child elements of this particular parent.
    # Information such as tag, parent-child relationship, name, vr, length and value is gathered for each data element
    # and processed to produce a nicely formatted output.
    # Returns an array of formatted data elements.
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:value_max</tt> -- Fixnum. If a value max length is specified, the data elements who's value exceeds this length will be trimmed to this length.
    # * <tt>:file</tt> -- String. If a file path is specified, the output will be printed to this file instead of being printed to the screen.
    #
    # === Examples
    #
    #   # Print a DObject instance to screen
    #   obj.print
    #   # Print the obj to the screen, but specify a 25 character value cutoff to produce better-looking results:
    #   obj.print(:value_max => 25)
    #   # Print to a text file the elements that belong to a specific Sequence:
    #   obj["3006,0020"].print(:file => "dicom.txt")
    #
    #--
    # FIXME: Perhaps a :children => false option would be a good idea (to avoid lengthy printouts in cases where this would be desirable)?
    # FIXME: Speed. The new print algorithm may seem to be slower than the old one (observed on complex, hiearchical DICOM files). Perhaps it can be optimized?
    #
    def print(options={})
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

    # Finds and returns the maximum character lengths of name and length which occurs for any child element,
    # as well as the maximum number of generations of elements.
    #
    # === Notes
    #
    # This method is not intended for external use, but for technical reasons (the fact that is called between
    # instances of different classes), cannot be made private.
    #
    # The method is used by the print() method to achieve a proper format in its output.
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

    # Removes the specified element from this parent.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A tag string which specifies the element to be removed (Exception: In the case of an Item removal, an index (Fixnum) is used instead).
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:no_follow</tt> -- Boolean. If true, the method does not update the parent attribute of the child that is removed.
    #
    # === Examples
    #
    #   # Remove a DataElement from a DObject instance:
    #   obj.remove("0008,0090")
    #   # Remove Item 1 from a specific Sequence:
    #   obj["3006,0020"].remove(1)
    #
    def remove(tag, options={})
      if tag.is_a?(String) or tag.is_a?(Integer)
        raise ArgumentError, "Argument (#{tag}) is not a valid tag string." if tag.is_a?(String) && !tag.tag?
        raise ArgumentError, "Negative Integer argument (#{tag}) is not allowed." if tag.is_a?(Integer) && tag < 0
      else
        raise ArgumentError, "Expected String or Integer, got #{tag.class}."
      end
      # We need to delete the specified child element's parent reference in addition to removing it from the tag Hash.
      element = @tags[tag]
      if element
        element.parent = nil unless options[:no_follow]
        @tags.delete(tag)
      end
    end

    # Removes all child elements from this parent.
    #
    def remove_children
      @tags.each_key do |tag|
        remove(tag)
      end
    end

    # Removes all data elements of the specified group from this parent.
    #
    # === Parameters
    #
    # * <tt>group_string</tt> -- A group string (the first 4 characters of a tag string).
    #
    # === Examples
    #
    #   # Remove the File Meta Group of a DICOM object:
    #   obj.remove_group("0002")
    #
    def remove_group(group_string)
      group_elements = group(group_string)
      group_elements.each do |element|
        remove(element.tag)
      end
    end

    # Removes all private data elements from the child elements of this parent.
    #
    # === Examples
    #
    #   # Remove all private elements from a DObject instance:
    #   obj.remove_private
    #   # Remove only private elements belonging to a specific Sequence:
    #   obj["3006,0020"].remove_private
    #
    def remove_private
      # Iterate all children, and repeat recursively if a child itself has children, to remove all private data elements:
      children.each do |element|
        remove(element.tag) if element.tag.private?
        element.remove_private if element.children?
      end
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

    # Returns true if the parent responds to the given method (symbol) (method is defined).
    # Returns false if the method is not defined.
    #
    # === Parameters
    #
    # * <tt>method</tt> -- Symbol. A method name who's response is tested.
    # * <tt>include_private</tt> -- (Not used by ruby-dicom) Boolean. If true, private methods are included in the search.
    #
    def respond_to?(method, include_private=false)
      # Check the library for a tag corresponding to the given method name symbol:
      return true unless LIBRARY.as_tag(method.to_s).nil?
      # In case of a query (xxx?) or assign (xxx=), remove last character and try again:
      return true unless LIBRARY.as_tag(method.to_s[0..-2]).nil?
      # Forward to Object#respond_to?:
      super
    end

    # Returns all child sequences of this parent in an array.
    # If no child sequences exists, returns an empty array.
    #
    def sequences
      children.select { |child| child.is_a?(Sequence) }
    end

    # A boolean which indicates whether the parent has any child sequences.
    #
    def sequences?
      sequences.any?
    end

    # Builds and returns a nested hash containing all children of this parent.
    # Keys are determined by the key_representation attribute, and data element values are used as values.
    #
    # === Notes
    #
    # * For private elements, the tag is used for key instead of the key representation, as private tags lacks names.
    # * For child-less parents, the key_representation attribute is used as value.
    #
    def to_hash
      as_hash = nil
      unless children?
        as_hash = (self.tag.private?) ? self.tag : self.send(DICOM.key_representation)
      else
        as_hash = Hash.new
        children.each do |child|
          if child.tag.private?
            hash_key = child.tag
          elsif child.is_a?(Item)
            hash_key = "Item #{child.index}"
          else
            hash_key = child.send(DICOM.key_representation)
          end
          as_hash[hash_key] = child.to_hash
        end
      end
      return as_hash
    end

    # Returns a json string containing a human-readable representation of the element.
    #
    def to_json
      to_hash.to_json
    end

    # Returns a yaml string containing a human-readable representation of the element.
    #
    def to_yaml
      to_hash.to_yaml
    end

    # Returns the value of a specific DataElement child of this parent.
    # Returns nil if the child element does not exist.
    #
    # === Notes
    #
    # * Only DataElement instances have values. Parent elements like Sequence and Item have no value themselves.
    #   If the specified <tt>tag</tt> is that of a parent element, <tt>value()</tt> will raise an exception.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A tag string which identifies the child DataElement.
    #
    # === Examples
    #
    #   # Get the patient's name value:
    #   name = obj.value("0010,0010")
    #   # Get the Frame of Reference UID from the first item in the Referenced Frame of Reference Sequence:
    #   uid = obj["3006,0010"][0].value("0020,0052")
    #
    def value(tag)
      if tag.is_a?(String) or tag.is_a?(Integer)
        raise ArgumentError, "Argument (#{tag}) is not a valid tag string." if tag.is_a?(String) && !tag.tag?
        raise ArgumentError, "Negative Integer argument (#{tag}) is not allowed." if tag.is_a?(Integer) && tag < 0
      else
        raise ArgumentError, "Expected String or Integer, got #{tag.class}."
      end
      if exists?(tag)
        if @tags[tag].is_parent?
          raise ArgumentError, "Illegal parameter '#{tag}'. Parent elements, like the referenced '#{@tags[tag].class}', have no value. Only DataElement tags are valid."
        else
          return @tags[tag].value
        end
      else
        return nil
      end
    end


    # Following methods are private:
    private


    # Re-encodes the value of a child DataElement (but only if the DataElement encoding is
    # influenced by a shift in endianness).
    #
    # === Parameters
    #
    # * <tt>element</tt> -- The DataElement who's value will be re-encoded.
    # * <tt>old_endian</tt> -- The previous endianness of the element binary (used for decoding the value).
    #
    #--
    # FIXME: Tag with VR AT has no re-encoding yet..
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

    # Prints an array of data element ascii text lines gathered by the print() method to file.
    #
    # === Parameters
    #
    # * <tt>elements</tt> -- An array of formatted data element lines.
    # * <tt>file</tt> -- A path & file string.
    #
    def print_file(elements, file)
      File.open(file, 'w') do |output|
        elements.each do |line|
          output.print line + "\n"
        end
      end
    end

    # Prints an array of data element ascii text lines gathered by the print() method to the screen.
    #
    # === Parameters
    #
    # * <tt>elements</tt> -- An array of formatted data element lines.
    #
    def print_screen(elements)
      elements.each do |line|
        puts line
      end
    end

  end
end
