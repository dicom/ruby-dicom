#    Copyright 2010 Christoffer Lervag

module DICOM

  # Super class which contains common code for all parent elements (Item, Sequence and DObject).
  class SuperParent

    # Initialize common variables among the parent elements.
    # Only for internal use (should be private).
    def initialize_parent
      # All child data elements and sequences are stored in a hash where tag string is used as key:
      @tags = Hash.new
    end

    # Returns the child element, specified by a tag string in a Hash-like syntax.
    # If the requested tag doesn't exist, nil is returned.
    # NB! Only immediate children are searched. Grandchildren etc. are not included.
    def [](tag)
      return @tags[tag]
    end

    # Adds a Data or Sequence Element to self (which can be either DObject or an Item).
    # Items are not allowed to be added with this method.
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
    # NB! Items are specified by index (starting at 1) instead of a tag string.
    def add_item(item=nil)
      unless self.is_a?(DObject)
        if item
          if item.is_a?(Item)
            # Add the existing Item to this Sequence:
            index = @tags.length + 1
            @tags[index] = item
            # Let the Item know what index key it's got in it's parent's Hash:
            item.index = index
          else
            raise "The specified parameter is not an Item. Only Items are allowed to be added to a Sequence."
          end
        else
          # Create an empty Item with self as parent.
          index = @tags.length + 1
          item = Item.new(ITEM_TAG, 0, :parent => self)
        end
      else
        raise "An Item #{item} was attempted added to a DObject instance #{self}, which is not allowed."
      end
    end

    # Returns all (immediate) child elements in an array (sorted by element tag).
    # If this particular parent doesn't have any children, an empty array is returned
    def children
      return @tags.sort.transpose[1] || Array.new
    end

    # A boolean used to check whether whether or not an element actually has any child elements.
    # Returns true if this parent have any child elements, false if not.
    def children?
      if @tags.length > 0
        return true
      else
        return false
      end
    end

    # Returns the number of Elements contained directly in this parent (does not include number of elements of possible children).
    def count
      return @tags.length
    end

    # Returns the total number of Elements contained in this parent (includes elements contained in possible child elements).
    def count_all
      # Search recursively through all child elements that are parents themselves.
      total_count = count
      @tags.each_value do |value|
        total_count += value.count_all if value.children?
      end
      return total_count
    end

    # Checks whether a given tag is defined for this parent. Returns true if a match is found, false if not.
    def exists?(tag)
      if @tags[tag]
        return true
      else
        return false
      end
    end

    # Handles the print job.
    # Only for internal use (should be private).
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
        tag = "#{visualization.join}#{element.tag}" #if visualization.length > 0
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

    # A boolean used to check whether or not an element is a parent.
    # Returns true.
    def is_parent?
      return true
    end

    # Sets the length of a Sequence or Item.
    def length=(new_length)
      unless self.is_a?(DObject)
        @length = new_length
      else
        raise "Length can not be set for DObject."
      end
    end

    # Prints the Elements contained in this Sequence/Item/DObject to the screen.
    # This method gathers the information that is necessary to produce a nicely formatted printout,
    # then passes the job on to the recursive handle_print() method.
    # Options:
    # :value_max
    # :file
    def print(options={})
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
        puts "Notice: Object #{self} is empty (contains no Data Elements)!"
      end
    end

    # Finds and returns the maximum length of Name and Length which occurs for any child element,
    # as well as the maximum number of generations of elements.
    # This is used by the print method to achieve pretty printing.
    # Only for internal use (should be private).
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

    # Removes an element from this parent.
    # The parameter is normally a tag String, except in the case of an Item, where an index number is used.
    def remove(tag)
      # We need to delete the specified child element's parent reference in addition to removing it from the tag Hash.
      element = @tags[tag]
      if element
        element.parent = nil
        @tags.delete(tag)
      end
    end

    # Removes all private data elements from the child elements of this parent.
    def remove_private
      # Cycle through all levels of children recursively and remove private data elements:
      children.each do |element|
        remove(element.tag) if element.tag.private?
        element.remove_private if element.children?
      end
    end

    # Resets the length of a Sequence or Item to -1 (the 'undefined' length).
    def reset_length
      unless self.is_a?(DObject)
        @length = -1
        @bin = ""
      else
        raise "Length can not be set for DObject."
      end
    end

    # Returns the value of a child of this instance, specified by the tag parameter.
    # If the child element does not exist, nil is returned.
    def value(tag)
      if exists?(tag)
        return @tags[tag].value
      else
        return nil
      end
    end

    # Following methods are private:
    private

    # Prints an array of Data Element ascii text lines gathered by the print() method to a file (specified by the user).
    def print_file(elements, file)
      File.open(file, 'w') do |output|
        elements.each do |line|
          output.print line + "\n"
        end
      end
    end

    # Prints an array of Data Element ascii text lines gathered by the print() method to the screen (terminal).
    def print_screen(elements)
      elements.each do |line|
        puts line
      end
    end

  end # of class
end # of module
