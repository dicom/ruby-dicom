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

    # Returns true (a boolean used to check whether an element has children or not).
    def children?
      return true
    end

    # Returns all (immediate) child elements in a sorted array.
    def child_array
      return @tags.sort
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
      tree_symbol = "|_"
      last_item_symbol = "  "
      nonlast_item_symbol = "| "
      child_array.each_with_index do |child, i|
        # A two-element array where the first element is the tag string and the second is the Data/Item/Sequence element object.
        tag = child[0]
        element = child[1]
        n_parents = element.parents.length
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
            if child == child_array.first
              child_visualization = Array.new
              child_visualization.replace(visualization)
              if child_array.length == 1
                child_visualization.insert(2-n_parents, last_item_symbol)
              else
                child_visualization.insert(2-n_parents, nonlast_item_symbol)
              end
            elsif child == child_array.last
              child_visualization[2-n_parents] = last_item_symbol
            end
          elsif n_parents == 1
            child_visualization = Array.new(1, tree_symbol)
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
      max_name, max_length, max_generations = max_lengths
      max_digits = count_all.to_s.length
      visualization = Array.new
      elements, index = handle_print(start_index=1, max_digits, max_name, max_length, max_generations, visualization, options)
      if options[:file]
        print_file(elements, options[:file])
      else
        print_screen(elements)
      end
    end

    # Finds and returns the maximum length of Name and Length which occurs for any child element,
    # as well as the maximum number of generations of elements.
    # This is used by the print method to achieve pretty printing.
    def max_lengths
      max_name = 0
      max_length = 0
      max_generations = 0
      child_array.each do |child|
        element = child[1]
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
