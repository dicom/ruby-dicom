#    Copyright 2008-2010 Christoffer Lervag

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
    # * <tt>tag</tt> -- A tag String which identifies the data element to be returned (Exception: In the case where an Item is wanted, an index (Fixnum) is used instead).
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

    # Adds a DataElement or Sequence instance to self (where self can be either a DObject or Item instance).
    #
    # === Restrictions
    #
    # * Items can not be added with this method.
    #
    # === Parameters
    #
    # * <tt>element</tt> -- An element (DataElement or Sequence).
    #
    # === Examples
    #
    #   # Add the element roi_name to the first item in the specified sequence:
    #   obj["3006,0020"][1].add(roi_name)
    #
    def add(element)
      unless element.is_a?(Item)
        unless self.is_a?(Sequence)
          # If we are replacing an existing Element, we need to make sure that this Element's parent value is erased before proceeding.
          self[element.tag].parent = nil if exists?(element.tag)
          # Add the element:
          @tags[element.tag] = element
        else
          raise "A Sequence is not allowed to have elements added to it. Use the method add_item() instead if the intention is to add an Item."
        end
      else
        raise "An Item is not allowed as a parameter to the add() method. Use add_item() instead."
      end
    end

    # Adds a child item to a Sequence (or Item in some cases where pixel data is encapsulated).
    # If no existing Item is specified, an empty item will be added.
    #
    # === Notes
    # * Items are specified by index (starting at 1) instead of a tag String!
    #
    # === Parameters
    #
    # * <tt>item</tt> -- The Item instance that is to be added (defaults to nil, in which case an empty Item will be added).
    # * <tt>options</tt> -- A Hash of parameters.
    #
    # === Options
    #
    # * <tt>:index</tt> -- Fixnum. If the Item is to be inserted at a specific index (Item number), this option parameter needs to set.
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
              if options[:index] >= 1
                # If the index value is larger than the max index present, we dont need to modify the existing items.
                unless options[:index] > @tags.length
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
                  options[:index] = @tags.length + 1
                end
                #,Add the new Item and set its index:
                @tags[options[:index]] = item
                item.index = options[:index]
              else
                raise "The specified index (#{options[:index]}) is out of range (Minimum allowed index value is 1)."
              end
            else
              # Add the existing Item to this Sequence:
              index = @tags.length + 1
              @tags[index] = item
              # Let the Item know what index key it's got in it's parent's Hash:
              item.index = index
            end
          else
            raise "The specified parameter is not an Item. Only Items are allowed to be added to a Sequence."
          end
        else
          # Create an empty Item with self as parent.
          index = @tags.length + 1
          item = Item.new(:parent => self)
        end
      else
        raise "An Item #{item} was attempted added to a DObject instance #{self}, which is not allowed."
      end
    end

    # Returns all (immediate) child elements in an array (sorted by element tag).
    # If this particular parent doesn't have any children, an empty array is returned
    #
    def children
      return @tags.sort.transpose[1] || Array.new
    end

    # Checks if an element actually has any child elements.
    # Returns true if it has and false if it doesn't.
    #
    # === Notes
    #
    # * Notice the subtle difference between the children? and is_parent? methods. While they
    # will give the same result in most real use cases, they differ when used on parent elements
    # that do not have any children added yet.
    # * For example, when called on an empty Sequence, the children? method will return false,
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

    # Re-encodes the binary data strings of all child Data Elements.
    # This also includes all the elements contained in any possible child elements.
    #
    # === Notes
    #
    # * This method is not intended for external use, but for technical reasons (the fact that is called between
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
    # * <tt>tag</tt> -- A tag String which identifies the data element that is queried (Exception: In the case of an Item query, an index (Fixnum) is used instead).
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

    # Gathers the desired information from the selected data elements and processes this information to make
    # a text output which is nicely formatted. Returns a text Array and an index (Fixnum) of the last data element.
    #
    # === Notes
    #
    # * This method is not intended for external use, but for technical reasons (the fact that is called between
    # instances of different classes), cannot be made private.
    # * The method is used by the print() method to construct the text output.
    #
    # === Parameters
    #
    # * <tt>index</tt> -- Fixnum. The index which is given to the first child of this parent.
    # * <tt>max_digits</tt> -- Fixnum. The maximum number of digits in the index of an element (which is the index of the last element).
    # * <tt>max_name</tt> -- Fixnum. The maximum number of characters in the name of any element to be printed.
    # * <tt>max_length</tt> -- Fixnum. The maximum number of digits in the length of an element.
    # * <tt>max_generations</tt> -- Fixnum. The maximum number of generations of children for this parent.
    # * <tt>visualization</tt> -- An Array of String symbols which visualizes the tree structure that the children of this particular parent belongs to. For no visualization, an empty Array is passed.
    # * <tt>options</tt> -- A Hash of parameters.
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
          name = "#{element.name} (\##{i+1})"
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

    # Checks if an element is a parent.
    # Returns true for all parent elements.
    #
    def is_parent?
      return true
    end

    # Sets the length of a Sequence or Item.
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
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A Hash of parameters.
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
    end

    # Finds and returns the maximum character lengths of name and length which occurs for any child element,
    # as well as the maximum number of generations of elements.
    #
    # === Notes
    #
    # * This method is not intended for external use, but for technical reasons (the fact that is called between
    # instances of different classes), cannot be made private.
    # * The method is used by the print() method to achieve a proper format in its output.
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
    # * <tt>tag</tt> -- A tag String which specifies the element to be removed (Exception: In the case of an Item removal, an index (Fixnum) is used instead).
    #
    # === Examples
    #
    #   # Remove a DataElement from a DObject instance:
    #   obj.remove("0008,0090")
    #   # Remove Item 1 from a specific Sequence:
    #   obj["3006,0020"].remove(1)
    #
    def remove(tag)
      # We need to delete the specified child element's parent reference in addition to removing it from the tag Hash.
      element = @tags[tag]
      if element
        element.parent = nil
        @tags.delete(tag)
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
    #   uid = obj["3006,0010"][1].value("0020,0052")
    #
    def value(tag)
      if exists?(tag)
        if @tags[tag].is_parent?
          raise "Illegal parameter '#{tag}'. Parent elements, like the referenced '#{@tags[tag].class}', have no value. Only DataElement tags are valid."
        else
          return @tags[tag].value
        end
      else
        return nil
      end
    end


    # Following methods are private:
    private


    # Re-encodes the value of a child Data Element (but only if the Data Element encoding is
    # influenced by a shift in endianness).
    #
    # === Parameters
    #
    # * <tt>element</tt> -- The DataElement who's value will be re-encoded.
    # * <tt>old_endian</tt> -- The previous endianness of the element binary (used for decoding the value).
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
          when "US", "SS", "UL", "SL", "FL", "FD", "OF", "OW" # Numbers
            # Re-encode, as long as it is not a group 0002 element (which must always be little endian):
            unless element.tag.group == "0002"
              stream_old_endian = Stream.new(element.bin, old_endian)
              numbers = stream_old_endian.decode(element.length, element.vr)
              element.value = numbers
            end
          #when "AT" # Tag reference
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
    # * <tt>elements</tt> -- An Array of formatted data element lines.
    # * <tt>file</tt> -- A path & file String.
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
    # * <tt>elements</tt> -- An Array of formatted data element lines.
    #
    def print_screen(elements)
      elements.each do |line|
        puts line
      end
    end

  end
end
