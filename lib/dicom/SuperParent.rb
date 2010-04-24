#    Copyright 2010 Christoffer Lervag

module DICOM

  # Super class which contains common code for all parent elements (Item, Sequence and DObject).
  class SuperParent

    attr_reader :children

    # Initialize common variables among the parent elements.
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

    # Adds a Data or Sequence Element to self (self should be either a DObject or an Item).
    # Items are not allowed to be added with this method.
    def add(element)
      unless element.is_a?(Item)
        unless self.is_a?(Sequence)
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

    # Returns true (a boolean used to check whether an element has children or not).
    def children?
      return true
    end

    # Returns all (immediate) child elements in a sorted array. If object has no children, an empty array is returned
    def child_array
      return @tags.sort.transpose[1] || Array.new
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
    def handle_print(index, max_digits, max_name, max_length, max_generations, visualization, options={})
      elements = Array.new
      s = " "
      hook_symbol = "|_"
      last_item_symbol = "  "
      nonlast_item_symbol = "| "
      child_array.each_with_index do |element, i|
        n_parents = element.parents.length
        tag = element.tag
        # Formatting: Index
        i_s = s*(max_digits-(index).to_s.length)
        # Formatting: Name (and Tag)
        unless tag.is_a?(String)
          name = "#{element.name} (\##{tag})"
          tag = ITEM_TAG
        else
          name = element.name
        end
        n_s = s*(max_name-name.length)
        # Formatting: Tag
        tag = "#{visualization.join}#{tag}" if visualization.length > 0
        t_s = s*((max_generations-1)*2+9-tag.length)
        # Formatting: Length
        l_s = s*(max_length-element.length.to_s.length)
        # Formatting Value:
        value = element.value.to_s
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
            if element == child_array.first
              if child_array.length == 1
                # Last item:
                child_visualization.insert(n_parents-2, last_item_symbol)
              else
                # More items follows:
                child_visualization.insert(n_parents-2, nonlast_item_symbol)
              end
            elsif element == child_array.last
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
    def max_lengths
      max_name = 0
      max_length = 0
      max_generations = 0
      child_array.each do |element|
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
