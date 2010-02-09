#    Copyright 2008-2010 Christoffer Lervag
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#--------------------------------------------------------------------------------------------------

# TODO:
# -Improve the retrieve file network functionality
# -Make the networking more intelligent in its handling of (unexpected) messages
# -Support for writing complex (hierarchical) DICOM files (basic write support is featured).
# -Full support for compressed image data.
# -Read 12 bit image data correctly.
# -Support for color image data to get_image_narray and get_image_magick.
# -Complete support for Big endian (basic support is already featured).
# -Complete support for multiple frame image data to NArray and RMagick objects (partial support already featured).
# -Make the image handling more intelligent with respect to interpreting data elements that hold information on the image and its properties.

module DICOM

  # Class for interacting with the DICOM object.
  class DObject

    attr_reader :read_success, :write_success, :modality, :errors, :segments,
                      :names, :tags, :types, :lengths, :values, :raw, :levels

    # Initialize the DObject instance.
    def initialize(string=nil, options={})
      # Process option values, setting defaults for the ones that are not specified:
      @verbose = options[:verbose]
      segment_size = options[:segment_size]
      bin = options[:bin]
      syntax = options[:syntax]
      # Default verbosity is true:
      @verbose = true if @verbose == nil

      # Initialize variables that will be used for the DICOM object:
      @names = Array.new
      @tags = Array.new
      @types = Array.new
      @lengths = Array.new
      @values = Array.new
      @raw = Array.new
      @levels = Array.new
      # Array that will holde any messages generated while reading the DICOM file:
      @errors = Array.new
      # Array to keep track of sequences/structure of the dicom elements:
      @sequence = Array.new
      # Index of last element in data element arrays:
      @last_index=0
      # Structural information (default values):
      @compression = false
      @color = false
      @explicit = true
      @file_endian = false
      # Information about the DICOM object:
      @modality = nil
      # Control variables:
      @read_success = false
      # Initialize a Stream instance which is used for encoding/decoding:
      @stream = Stream.new(nil, @file_endian, @explicit)

      # If a (valid) file name string is supplied, call the method to read the DICOM file:
      if string.is_a?(String) and string != ""
        @file = string
        read(string, :bin => bin, :segment_size => segment_size, :syntax => syntax)
      end
    end # of initialize


    # Returns a DICOM object by reading the file specified.
    # This is accomplished by initliazing the DRead class, which loads DICOM information to arrays.
    # For the time being, this method is called automatically when initializing the DObject class,
    # but in the future, when write support is added, this method may have to be called manually.
    def read(string, options = {})
      r = DRead.new(string, :sys_endian => @sys_endian, :bin => options[:bin], :syntax => options[:syntax])
      # Store the data to the instance variables if the readout was a success:
      if r.success
        @read_success = true
        @names = r.names
        @tags = r.tags
        @types = r.types
        @lengths = r.lengths
        @values = r.values
        @raw = r.raw
        @levels = r.levels
        @explicit = r.explicit
        @file_endian = r.file_endian
        # Update Stream instance with settings from this DICOM file:
        @stream.set_endian(@file_endian)
        @stream.explicit = @explicit
        # Index of last data element in element arrays:
        @last_index=@names.length-1
        # Update status variables for this object:
        check_properties
        # Set the modality of the DICOM object:
        set_modality
      else
        @read_success = false
      end
      # Check if a partial extraction has been requested (used for network communication purposes)
      if options[:segment_size]
        @segments = r.extract_segments(options[:segment_size])
      end
      # If any messages has been recorded, send these to the message handling method:
      add_msg(r.msg) if r.msg.size != 0
    end


    # Transfers necessary information from the DObject to the DWrite class, which
    # will attempt to write this information to a valid DICOM file.
    def write(file_name, transfer_syntax = nil)
      w = set_write_object(file_name, transfer_syntax)
      w.write
      # Write process succesful?
      @write_success = w.success
      # If any messages has been recorded, send these to the message handling method:
      add_msg(w.msg) if w.msg.size != 0
    end


    # Encodes the DICOM object into a series of binary string segments with a specified maximum length.
    def encode_segments(size)
      w = set_write_object
      @segments = w.encode_segments(size)
      # Write process succesful?
      @write_success = w.success
      # If any messages has been recorded, send these to the message handling method:
      add_msg(w.msg) if w.msg.size != 0
    end


    #################################################
    # START OF METHODS FOR READING INFORMATION FROM DICOM OBJECT:
    #################################################


    # Returns a 3d NArray object where the array dimensions corresponds to [frames, columns, rows].
    # To call this method the user needs to loaded the NArray library in advance (require 'narray').
    # Options:
    # Some options to reorient the pixel matrix may be implemented here.
    def get_image_narray(options={})
      # Are we able to make a pixel array?
      if @compression == nil
        add_msg("It seems pixel data is not present in this DICOM object: Returning false.")
        return false
      elsif @compression == true
        add_msg("Reading compressed data to a NArray object not supported yet: Returning false.")
        return false
      elsif @color
        add_msg("Warning: Unpacking color pixel data is not supported yet for this method: Returning false.")
        return false
      end
      # Gather information about the dimensions of the pixel data:
      rows = get_value("0028,0010", :array => true)[0]
      columns = get_value("0028,0011", :array => true)[0]
      frames = get_frames
      pixel_element_pos = get_image_pos
      # A hack for the special case (some MR files), where two images are stored (one is a smaller thumbnail image):
      pixel_element_pos = [pixel_element_pos.last] if pixel_element_pos.length > 1 and get_value("0028,0011", :array => true).length > 1
      # Creating a NArray object using int to make sure we have the necessary range for our numbers:
      pixel_data = NArray.int(frames,columns,rows)
      pixel_frame = NArray.int(columns,rows)
      # Handling of pixel data will depend on whether we have one or more frames,
      # and if it is located in one or more data elements:
      if pixel_element_pos.length == 1
        # All of the pixel data is located in one element:
        pixel_array = get_pixels(pixel_element_pos[0])
        frames.times do |i|
          (columns*rows).times do |j|
            pixel_frame[j] = pixel_array[j+i*columns*rows]
          end
          pixel_data[i,true,true] = pixel_frame
        end
      else
        # Pixel data is encapsulated in items:
        frames.times do |i|
          pixel_array = get_pixels(pixel_element_pos[i])
          (columns*rows).times do |j|
            pixel_frame[j] = pixel_array[j+i*columns*rows]
          end
          pixel_data[i,true,true] = pixel_frame
        end
      end
      # Rearrange the pixel data to get the expected orientation when displaying it on the screen:
      # (This rearrangement is disabled and should ideally be replaced with a more principal, robust implementation.)
=begin
      frames.times do |i|
        temp_frame = pixel_data[i,true,true]
        # Transpose array:
        temp_frame.transpose(1,0)
        # Mirror the y-axis:
        temp_frame.shape[0].times do |j|
          temp_frame[j, 0..temp_frame.shape[1]-1] = temp_frame[j, temp_frame.shape[1]-1..0]
        end
        # Put the reoriented pixel data back in its original variable:
        pixel_data[i,true,true] = temp_frame
      end
=end
      return pixel_data
    end # of get_image_narray


    # Returns an array of RMagick image objects, where the size of the array corresponds to the number of frames in the image data.
    # To call this method the user needs to have loaded the ImageMagick library in advance (require 'RMagick').
    def get_image_magick(options={})
      # Are we able to make an image?
      if @compression == nil
        add_msg("It seems pixel data is not present in this DICOM object: Returning false.")
        return false
      elsif @color
        add_msg("Warning: Unpacking color pixel data is not supported yet for this method: Returning false.")
        return false
      end
      # Gather information about the dimensions of the image data:
      rows = get_value("0028,0010", :array => true)[0]
      columns = get_value("0028,0011", :array => true)[0]
      frames = get_frames
      pixel_element_pos = get_image_pos
      # Array that will hold the RMagick image objects, one object for each frame:
      images = Array.new(frames)
      # A hack for the special case (some MR files), where two images are stored (one is a smaller thumbnail image):
      pixel_element_pos = [pixel_element_pos.last] if pixel_element_pos.length > 1 and get_value("0028,0011", :array => true).length > 1
      # Handling of pixel data will depend on whether we have one or more frames,
      # and if it is located in one or more data elements:
      if pixel_element_pos.size == 1
        # All of the pixel data is located in one data element:
        if frames > 1
          add_msg("Unfortunately, this method only supports reading the first image frame as of now.")
        end
        images = read_image_magick(pixel_element_pos[0], columns, rows, frames, options)
        images = [images] unless images.is_a?(Array)
      else
        # Image data is encapsulated in items:
        frames.times do |i|
          image = read_image_magick(pixel_element_pos[i], columns, rows, 1, options)
          images[i] = image
        end
      end
      return images
    end # of get_image_magick


    # Returns the number of frames present in the image data in the DICOM file.
    def get_frames
      frames = get_value("0028,0008", :silent => true)
      # If the DICOM object does not specify the number of frames explicitly, assume 1 image frame:
      frames = 1 unless frames
      return frames.to_i
    end


    # Returns the index(es) of the element(s) that contain image data.
    def get_image_pos
      image_element_pos = get_pos("7FE0,0010")
      item_pos = get_pos("FFFE,E000")
      # Proceed only if an image element actually exists:
      if image_element_pos == false
        return false
      else
        # Check if we have item elements:
        if item_pos == false
          return image_element_pos
        else
          # Extract item positions that occur after the image element position:
          late_item_pos = item_pos.select {|item| image_element_pos[0] < item}
          # Check if there are items appearing after the image element.
          if late_item_pos.size == 0
            # None occured after the image element position:
            return image_element_pos
          else
            # Determine which of these late item elements contain image data.
            # Usually, there are frames+1 late items, and all except
            # the first item contain an image frame:
            frames = get_frames
            if frames != false  # note: function get_frames will never return false
              if late_item_pos.size == frames.to_i+1
                return late_item_pos[1..late_item_pos.size-1]
              else
                add_msg("Warning: Unexpected behaviour in DICOM file for method get_image_pos. Expected number of image data items not equal to number of frames+1, returning false.")
                return false
              end
            else
              add_msg("Warning: 'Number of Frames' data element not found. Method get_image_pos will return false.")
              return false
            end
          end
        end
      end
    end


    # Returns an array of the index(es) of the element(s) in the DICOM file that match the supplied element position, tag or name.
    # If no match is found, the method will return false.
    # Additional options:
    # :array => myArray - tells the method to search for matches in this specific array of positions instead of searching
    #                                  through the entire DICOM object. If myArray equals false, the method will return false.
    # :partial => true - get_pos will not only search for exact matches, but will search the names and tags arrays for
    #                             strings that contain the given search string.
    def get_pos(query, options={})
      indexes = Array.new
      # For convenience, allow query to be a one-element array (its value will be extracted):
      if query.is_a?(Array)
        if query.length > 1 or query.length == 0
          add_msg("Invalid array length supplied to method get_pos.")
          return false
        else
          query = query[0]
        end
      end
      if options[:array] == false
        # If the supplied array option equals false, it signals that the user tries to search for an element
        # in an invalid position, and as such, this method will also return false:
        add_msg("Warning: Attempted to call get_pos with query #{query}, but since keyword :array is false I will return false.")
        indexes = false
      else
        # Check if query is a number (some methods want to have the ability to call get_pos with a number):
        if query.is_a?(Integer)
          # Return the position if it is valid:
          indexes = [query] if query >= 0 and query < @names.length
        elsif query.is_a?(String)
          # Either use the supplied array, or search the entire DICOM object:
          if options[:array].is_a?(Array)
            search_array = options[:array]
          else
            search_array = Array.new(@names.length) {|i| i}
          end
          # Perform search:
          if options[:partial] == true
            # Search for partial string matches:
            partial_indexes = search_array.all_indices_partial_match(@tags, query.upcase)
            if partial_indexes.length > 0
              indexes = partial_indexes
            else
              indexes = search_array.all_indices_partial_match(@names, query)
            end
          else
            # Search for identical matches:
            if query[4..4] == ","
              indexes = search_array.all_indices(@tags, query.upcase)
            else
              indexes = search_array.all_indices(@names, query)
            end
          end
        end
        # Policy: If no matches found, return false instead of an empty array:
        indexes = false if indexes.length == 0
      end
      return indexes
    end # of get_pos


    # Dumps the binary content of the Pixel Data element to file.
    def image_to_file(file)
      pos = get_image_pos
      if pos
        if pos.length == 1
          # Pixel data located in one element:
          pixel_data = get_raw(pos[0])
          f = File.new(file, "wb")
          f.write(pixel_data)
          f.close
        else
          # Pixel data located in several elements:
          pos.each_index do |i|
            pixel_data = get_raw(pos[i])
            f = File.new(file + i.to_s, "wb")
            f.write(pixel_data)
            f.close
          end
        end
      end
    end


    # Returns the positions of all data elements inside the hierarchy of a sequence or an item.
    # Options:
    # :next_only => true - The method will only search immediately below the specified
    # item or sequence (that is, in the level of parent + 1).
    def children(element, options={})
      # Process option values, setting defaults for the ones that are not specified:
      opt_next_only = options[:next_only] || false
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method children. Returning false.")
      else
        if pos.size > 1
          add_msg("Warning: Method children does not allow a query which yields multiple array hits. Please use array position instead of tag/name. Returning false.")
        else
          # Proceed to find the value:
          # First we need to establish in which positions to perform the search:
          below_pos = Array.new
          pos.each do |p|
            parent_level = @levels[p]
            remain_array = @levels[p+1..@levels.size-1]
            extract = true
            remain_array.each_index do |i|
              if (remain_array[i] > parent_level) and (extract == true)
                # If search is targetted at any specific level, we can just add this position:
                if not opt_next_only == true
                  below_pos << (p+1+i)
                else
                  # As search is restricted to parent level + 1, do a test for this:
                  if remain_array[i] == parent_level + 1
                    below_pos << (p+1+i)
                  end
                end
              else
                # If we encounter a position who's level is not deeper than the original level, we can not extract any more values:
                extract = false
              end
            end
          end
          value = below_pos if below_pos.size != 0
        end
      end
      return value
    end


    # Returns the value (processed raw data) of the requested DICOM data element.
    # Data element may be specified by array position, tag or name.
    # Options:
    # :array => true - Allows the query of the value of a tag that occurs more than one time in the
    #                  DICOM object. Values will be returned in an array with length equal to the number
    #                  of occurances of the tag. If keyword is not specified, the method returns false in this case.
    # :silent => true - As this method is also used internally, we want the possibility of warnings not being
    #                  raised even if verbose is set to true by the user, in order to avoid confusion.
    def get_value(element, options={})
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method get_value. Returning false.") unless options[:silent]
      else
        if pos.size > 1
          # Multiple 'hits':
          if options[:array] == true
            # Retrieve all values into an array:
            value = Array.new
            pos.each do |i|
              value << @values[i]
            end
          else
            add_msg("Warning: Method get_value does not allow a query which yields multiple array hits. Please use array position instead of tag/name, or use keyword (:array => true). Returning false.") unless options[:silent]
          end
        else
          # One single match:
          value = @values[pos[0]]
          # Return the single value in an array if keyword :array used:
          value = [value] if options[:array]
        end
      end
      return value
    end


    # Returns the raw data of the requested DICOM data element.
    # Data element may be specified by array position, tag or name.
    # Options:
    # :array => true - Allows the query of the value of a tag that occurs more than one time in the
    #                  DICOM object. Values will be returned in an array with length equal to the number
    #                  of occurances of the tag. If keyword is not specified, the method returns false in this case.
    def get_raw(element, options={})
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method get_raw. Returning false.")
      else
        if pos.size > 1
          # Multiple 'hits':
          if options[:array] == true
            # Retrieve all values into an array:
            value = Array.new
            pos.each do |i|
              value << @raw[i]
            end
          else
            add_msg("Warning: Method get_raw does not allow a query which yields multiple array hits. Please use array position instead of tag/name, or use keyword (:array => true). Returning false.")
          end
        else
          # One single match:
          value = @raw[pos[0]]
          # Return the single value in an array if keyword :array used:
          value = [value] if options[:array]
        end
      end
      return value
    end


    # Returns the position of (possible) parents of the specified data element in the hierarchy structure of the DICOM object.
    def parents(element)
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method parents. Returning false.")
      else
        if pos.length > 1
          add_msg("Warning: Method parents does not allow a query which yields multiple array hits. Please use array position instead of tag/name. Returning false.")
        else
          # Proceed to find the value:
          # Get the level of our element:
          level = @levels[pos[0]]
          # Element can obviously only have parents if it is not a top level element:
          unless level == 0
            # Search backwards, and record the position every time we encounter an upwards change in the level number.
            parents = Array.new
            prev_level = level
            search_arr = @levels[0..pos[0]-1].reverse
            search_arr.each_index do |i|
              if search_arr[i] < prev_level
                parents << search_arr.length-i-1
                prev_level = search_arr[i]
              end
            end
            # When the element has several generations of parents, we want its top parent to be first in the returned array:
            parents = parents.reverse
            value = parents if parents.length > 0
          end
        end
      end
      return value
    end


    ##############################################
    ####### START OF METHODS FOR PRINTING INFORMATION:######
    ##############################################


    # Prints the information of all elements stored in the DICOM object.
    # This method is kept for backwards compatibility.
    # Instead of calling print_all you may use print(true) for the same functionality.
    def print_all
      print(true)
    end


    # Prints the information of the specified elements: Index, [hierarchy level, tree visualisation,] tag, name, type, length, value
    # The supplied variable may be a single position, an array of positions, or true - which will make the method print all elements.
    # Optional arguments:
    # :levels => true - method will print the level numbers for each element.
    # :tree => true -   method will print a tree structure for the elements.
    # :file => true -    method will print to file instead of printing to screen.
    def print(pos, options={})
      # Process option values, setting defaults for the ones that are not specified:
      opt_levels = options[:levels] || false
      opt_tree = options[:tree] || false
      opt_file = options[:file] || false
      # If pos is false, abort, and inform the user:
      if pos == false
        add_msg("Warning: Method print was supplied false instead of a valid position. Aborting print.")
        return
      end
      if not pos.is_a?(Array) and pos != true
        # Convert to array if number:
        pos_valid = [pos]
      elsif pos == true
        # Create a complete array of indices:
        pos_valid = Array.new(@names.length) {|i| i}
      else
        # Use the supplied array of numbers:
        pos_valid = pos
      end
      # Extract the information to be printed from the object arrays:
      indices = Array.new
      levels = Array.new
      tags = Array.new
      names = Array.new
      types = Array.new
      lengths = Array.new
      values = Array.new
      # There may be a more elegant way to do this.
      pos_valid.each do |pos|
        tags << @tags[pos]
        levels << @levels[pos].to_s
        names << @names[pos]
        types << @types[pos]
        lengths << @lengths[pos].to_s
        values << @values[pos].to_s
      end
      # We have collected the data that is to be printed, now we need to do some string manipulation if hierarchy is to be displayed:
      if opt_tree
        # Tree structure requested.
        front_symbol = "| "
        tree_symbol = "|_"
        tags.each_index do |i|
          if levels[i] != "0"
            tags[i] = front_symbol*(levels[i].to_i-1) + tree_symbol + tags[i]
          end
        end
      end
      # Extract the string lengths which are needed to make the formatting nice:
      tag_lengths = Array.new
      lev_lengths = Array.new
      name_lengths = Array.new
      type_lengths = Array.new
      length_lengths = Array.new
      names.each_index do |i|
        tag_lengths[i] = tags[i].length
        lev_lengths[i] = levels[i].length
        name_lengths[i] = names[i].length
        type_lengths[i] = types[i].length
        length_lengths[i] = lengths[i].to_s.length
      end
      # To give the printed output a nice format we need to check the string lengths of some of these arrays:
      index_maxL = pos_valid.max.to_s.length
      lev_maxL = lev_lengths.max
      tag_maxL = tag_lengths.max
      name_maxL = name_lengths.max
      type_maxL = type_lengths.max
      length_maxL = length_lengths.max
      # Construct the strings, one for each line of output, where each line contain the information of one data element:
      elements = Array.new
      # Start of loop which formats the element data:
      # (This loop is what consumes most of the computing time of this method)
      tags.each_index do |i|
        # Configure empty spaces:
        s = " "
        f0 = " "*(index_maxL-pos_valid[i].to_s.length)
        f1 = " "*(lev_maxL-levels[i].length)
        f2 = " "*(tag_maxL-tags[i].length+1)
        f3 = " "*(name_maxL-names[i].length+1)
        f4 = " "*(type_maxL-types[i].length+1)
        f5 = " "*(length_maxL-lengths[i].length)
        # Display levels?
        if opt_levels
          lev = levels[i] + f1
        else
          lev = ""
        end
        # Restrict length of value string:
        if values[i].length > 28
          value = (values[i])[0..27]+" ..."
        else
          value = (values[i])
        end
        # Insert descriptive text for elements that hold binary data:
        case types[i]
          when "OW","OB","UN"
            value = "(Binary Data)"
          when "SQ"
            value = "(Encapsulated Elements)"
          when "()"
            if tags[i].include?("FFFE,E000") # (Item)
              value = "(Encapsulated Elements)"
            else
              value = ""
            end
        end
        elements << (f0 + pos_valid[i].to_s + s + lev + s + tags[i] + f2 + names[i] + f3 + types[i] + f4 + f5 + lengths[i].to_s + s + s + value.rstrip)
      end
      # Print to either screen or file, depending on what the user requested:
      if opt_file
        print_file(elements)
      else
        print_screen(elements)
      end
    end # of print


    # Prints the key structural properties of the DICOM file.
    def print_properties
      # Explicitness:
      if @explicit
        explicit = "Explicit"
      else
        explicit = "Implicit"
      end
      # Endianness:
      if @file_endian
        endian = "Big Endian"
      else
        endian = "Little Endian"
      end
      # Pixel data:
      if @compression == nil
        pixels = "No"
      else
        pixels = "Yes"
      end
      # Colors:
      if @color
        image = "Colors"
      else
        image = "Greyscale"
      end
      # Compression:
      if @compression == true
        compression = LIBRARY.get_uid(get_value("0002,0010").rstrip)
      else
        compression = "No"
      end
      # Bits per pixel (allocated):
      bits = get_value("0028,0100", :array => true, :silent => true)
      bits = bits[0].to_s if bits
      # Print the file properties:
      puts "Key properties of DICOM object:"
      puts "-------------------------------"
      puts "File:           " + @file
      puts "Modality:       " + @modality.to_s
      puts "Value repr.:    " + explicit
      puts "Byte order:     " + endian
      puts "Pixel data:     " + pixels
      if pixels == "Yes"
        puts "Image:          " + image if image
        puts "Compression:    " + compression if compression
        puts "Bits per pixel: " + bits if bits
      end
      puts "-------------------------------"
    end # of print_properties


    ####################################################
    ### START OF METHODS FOR WRITING INFORMATION TO THE DICOM OBJECT:
    ####################################################


    # Reads binary information from file and inserts it in the pixel data element:
    def set_image_file(file)
      # Try to read file:
      begin
        f = File.new(file, "rb")
        bin = f.read(f.stat.size)
      rescue
        # Reading file was not successful. Register an error message.
        add_msg("Reading specified file was not successful for some reason. No data has been added.")
        return
      end
      if bin.length > 0
        pos = @tags.index("7FE0,0010")
        # Modify element:
        set_value(bin, "7FE0,0010", :create => true, :bin => true)
      else
        add_msg("Content of file is of zero length. Nothing to store.")
      end
    end


    # Transfers pixel data from a RMagick object to the pixel data element:
    def set_image_magick(magick_obj)
      # Export the RMagick object to a standard Ruby array of numbers:
      pixel_array = magick_obj.export_pixels(x=0, y=0, columns=magick_obj.columns, rows=magick_obj.rows, map="I")
      # Encode this array using the standard class method:
      set_value(pixel_array, "7FE0,0010", :create => true)
    end


    # Removes an element from the DICOM object.
    # Options:
    # :ignore_children => true  - Force the method to ignore children when removing an element.
    #    (default behaviour is to remove any children if a sequence or item is removed)
    def remove(element, options={})
      positions = get_pos(element)
      if positions != false
        if positions.length > 1
          add_msg("Warning: Method remove does not allow an element query which yields multiple array hits. Please use array position instead of tag/name. Value NOT removed.")
        else
          # Check if the tag selected for removal has children (relevant for sequence/item tags):
          unless options[:ignore_children]
            child_pos = children(positions)
            if child_pos
              # Add the positions of the children to our original tag's position array:
              positions << child_pos
            end
          end
          positions.flatten!
          # Loop through all positions (important to do this in reverse to retain predictable array positions):
          positions.reverse.each do |pos|
            # Update group length
            # (Possible weakness: Group length tag contained inside a sequence/item. Code needs a slight rewrite to make it more robust)
            if @tags[pos][5..8] != "0000"
              # Note: When removing an item/sequence, its length value must not be used for 'change' (it's value is in reality nil):
              if @types[pos] == "()" or @types[pos] == "SQ"
                change = 0
              else
                change = @lengths[pos]
              end
              vr = @types[pos]
              update_group_and_parents_length(pos, vr, change, -1)
            end
            # Remove entry from arrays:
            @tags.delete_at(pos)
            @levels.delete_at(pos)
            @names.delete_at(pos)
            @types.delete_at(pos)
            @lengths.delete_at(pos)
            @values.delete_at(pos)
            @raw.delete_at(pos)
          end
        end
      else
        add_msg("Warning: The data element #{element} could not be found in the DICOM object. Method remove has no data element to remove.")
      end
    end


    # Removes all private data elements from the DICOM object.
    def remove_private
      # Private data elemements have a group tag that is odd.
      odd_group = ["1,","3,","5,","7,","9,","B,","D,","F,"]
      odd_group.each do |odd|
        positions = get_pos(odd, :partial => true)
        if positions
          # Delete all entries (important to do this in reverse order).
          positions.reverse.each do |pos|
            remove(pos)
          end
        end
      end
    end


    # Sets the value of a data element by modifying an existing element or creating a new one.
    # If the supplied value is not binary, it will attempt to encode the value to binary itself.
    def set_value(value, element, options={})
      # Options:
      create = options[:create] # =false means no element creation
      bin = options[:bin] # =true means value already encoded
      vr = options[:vr] # a string which tells us what kind of type an unknown data element is
      # Retrieve array position:
      pos = get_pos(element)
      # We do not support changing multiple data elements:
      if pos.is_a?(Array)
        if pos.length > 1
          add_msg("Warning: Method set_value does not allow an element query which yields multiple array hits. Please use array position instead of tag/name. Value NOT saved.")
          return
        end
      end
      if pos == false and create == false
        # Since user has requested an element shall only be updated, we can not do so as the element position is not valid:
        add_msg("Warning: Invalid data element provided to method set_value. Value NOT updated.")
      elsif create == false
        # Modify element:
        modify_element(value, pos[0], :bin => bin)
      else
        # User wants to create an element (or modify it if it is already present).
        unless pos == false
          # The data element already exist, so we modify instead of creating:
          modify_element(value, pos[0], :bin => bin)
        else
          # We need to create element:
          # In the case that name has been provided instead of a tag, check with the library first:
          tag = LIBRARY.get_tag(element)
          # If this doesnt give a match, we may be dealing with a private tag:
          tag = element unless tag
          unless element.is_a_tag?
            add_msg("Warning: Method set_value could not create data element, because the data element tag is invalid (Expected format of tags is 'GGGG,EEEE').")
          else
            # As we wish to create a new data element, we need to find out where to insert it in the element arrays:
            # We will do this by finding the array position of the last element that will (alphabetically/numerically) stay in front of this element.
            if @tags.size > 0
              # Search the array:
              index = -1
              quit = false
              while quit != true do
                if index+1 >= @tags.length # We have reached end of array.
                  quit = true
                elsif tag < @tags[index+1] and @levels[index+1] == 0 # We are past the correct position (only match against top level tags).
                  quit = true
                else # Increase index in anticipation of a 'hit'.
                  index += 1
                end
              end
            else
              # We are dealing with an empty DICOM object:
              index = nil
            end
            # The necessary information is gathered; create new data element:
            create_element(value, tag, index, :bin => bin, :vr => vr)
          end
        end
      end
    end # of set_value


    ##################################################
    ############## START OF PRIVATE METHODS:  ########
    ##################################################
    private


    # Adds a warning or error message to the instance array holding messages, and if verbose variable is true, prints the message as well.
    def add_msg(msg)
      puts msg if @verbose
      @errors << msg
      @errors.flatten
    end


    # Checks the status of the pixel data that has been read from the DICOM file: whether it exists at all and if its greyscale or color.
    # Modifies instance variable @color if color image is detected and instance variable @compression if no pixel data is detected.
    def check_properties
      # Check if pixel data is present:
      if @tags.index("7FE0,0010") == nil
        # No pixel data in DICOM file:
        @compression = nil
      else
        @compression = LIBRARY.get_compression(get_value("0002,0010", :silent => true))
      end
      # Set color variable as true if our object contain a color image:
      col_string = get_value("0028,0004", :silent => true)
      if col_string != false
        if (col_string.include? "RGB") or (col_string.include? "COLOR") or (col_string.include? "COLOUR")
          @color = true
        end
      end
    end


    # Creates a new data element:
    def create_element(value, tag, last_pos, options={})
      bin_only = options[:bin]
      vr = options[:vr].upcase if options[:vr].is_a?(String)
      # Fetch the VR:
      info = LIBRARY.get_name_vr(tag)
      vr = info[1] unless vr
      name = info[0]
      # Encode binary (if a binary is not provided):
      if bin_only == true
        # Data already encoded.
        bin = value
        value = nil
      else
        if vr != "UN"
          # Encode:
          bin = encode(value, vr)
        else
          add_msg("Error. Unable to encode data element value of unknown type (Value Representation)!")
        end
      end
      # Put the information of this data element into the arrays:
      if bin
        # 4 different scenarios: Array is empty, or: element is put in front, inside array, or at end of array:
        # NB! No support for hierarchy at this time! Defaulting to level = 0.
        if last_pos == nil
          # We have empty DICOM object:
          @tags = [tag]
          @levels = [0]
          @names = [name]
          @types = [vr]
          @lengths = [bin.length]
          @values = [value]
          @raw = [bin]
        elsif last_pos == -1
          # Insert in front of arrays:
          @tags = [tag] + @tags
          @levels = [0] + @levels
          @names = [name] + @names
          @types = [vr] + @types
          @lengths = [bin.length] + @lengths
          @values = [value] + @values
          @raw = [bin] + @raw
        elsif last_pos == @tags.length-1
          # Insert at end arrays:
          @tags = @tags + [tag]
          @levels = @levels + [0]
          @names = @names + [name]
          @types = @types + [vr]
          @lengths = @lengths + [bin.length]
          @values = @values + [value]
          @raw = @raw + [bin]
        else
          # Insert somewhere inside the array:
          @tags = @tags[0..last_pos] + [tag] + @tags[(last_pos+1)..(@tags.length-1)]
          @levels = @levels[0..last_pos] + [0] + @levels[(last_pos+1)..(@levels.length-1)]
          @names = @names[0..last_pos] + [name] + @names[(last_pos+1)..(@names.length-1)]
          @types = @types[0..last_pos] + [vr] + @types[(last_pos+1)..(@types.length-1)]
          @lengths = @lengths[0..last_pos] + [bin.length] + @lengths[(last_pos+1)..(@lengths.length-1)]
          @values = @values[0..last_pos] + [value] + @values[(last_pos+1)..(@values.length-1)]
          @raw = @raw[0..last_pos] + [bin] + @raw[(last_pos+1)..(@raw.length-1)]
        end
        # Update last index variable as we have added to our arrays:
        @last_index += 1
        # Update group length (as long as it was not a group length element that was created):
        pos = @tags.index(tag)
        if @tags[pos][5..8] != "0000"
          change = bin.length
          update_group_and_parents_length(pos, vr, change, 1)
        end
      else
        add_msg("Binary is nil. Nothing to save.")
      end
    end # of create_element


    # Encodes a value to binary (used for inserting values into a DICOM object).
    def encode(value, vr)
      # VR will decide how to encode this value:
      case vr
        when "AT" # (Data element tag: Assume it has the format "GGGG,EEEE"
          if value.is_a_tag?
            bin = @stream.encode_tag(value)
          else
            add_msg("Invalid tag format (#{value}). Expected format: 'GGGG,EEEE'")
          end
        # We have a number of VRs that are encoded as string:
        when 'AE','AS','CS','DA','DS','DT','IS','LO','LT','PN','SH','ST','TM','UI','UT'
          # In case we are dealing with a number string element, the supplied value might be a number
          # instead of a string, and as such, we convert to string just to make sure this will work nicely:
          value = value.to_s
          bin = @stream.encode_value(value, "STR")
        # Image related value representations:
        when "OW"
          # What bit depth to use when encoding the pixel data?
          bit_depth = get_value("0028,0100")
          if bit_depth == false
            # Data element not specified:
            add_msg("Attempted to encode pixel data, but 'Bit Depth' data element is missing (0028,0100).")
          else
            # 8,12 or 16 bits?
            case bit_depth
              when 8
                bin = @stream.encode(value, "BY")
              when 12
                # 12 bit not supported yet!
                add_msg("Encoding 12 bit pixel values not supported yet. Please change the bit depth to 8 or 16 bits.")
              when 16
                bin = @stream.encode(value, "US")
              else
                # Unknown bit depth:
                add_msg("Unknown bit depth #{bit_depth}. No data encoded.")
            end
          end
        # All other VR's:
        else
          # Just encode:
          bin = @stream.encode(value, vr)
      end
      return bin
    end # of encode


    # Find the position(s) of the group length tag(s) that the given tag is associated with.
    # If a group length tag does not exist, return false.
    def find_group_length(pos)
      positions = Array.new
      group = @tags[pos][0..4]
      # Check if our tag is part of a sequence/item:
      if @levels[pos] > 0
        # Add (possible) group length of top parent:
        parent_positions = parents(pos)
        first_parent_gl_pos = find_group_length(parent_positions.first)
        positions << first_parent_gl_pos.first if first_parent_gl_pos
        # Add (possible) group length at current tag's level:
        valid_positions = children(parent_positions.last)
        level_gl_pos = get_pos(group+"0000", :array => valid_positions)
        positions << level_gl_pos.first if level_gl_pos
      else
        # We are dealing with a top level tag:
        gl_pos = get_pos(group+"0000")
        # Note: Group level tags of this type may be found elsewhere in the DICOM object inside other
        # sequences/items. We must make sure that such tags are not added to our list:
        if gl_pos
          gl_pos.each do |gl|
            positions << gl if @levels[gl] == 0
          end
        end
      end
      # If we didnt find any positions, we return false:
      positions = false unless positions.length > 0
      return positions
    end


    # Unpacks and returns pixel data from a specified data element array position:
    def get_pixels(pos)
      pixels = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth = get_value("0028,0100", :array => true)[0]
      pixel_rep = get_value("0028,0103", :array => true)[0]
      unless bit_depth == false
        # Load the binary pixel data to the Stream instance:
        @stream.set_string(get_raw(pos))
        # Number of bytes used per pixel will determine how to unpack this:
        case bit_depth
          when 8
            pixels = @stream.decode_all("BY") # Byte/Character/Fixnum (1 byte)
          when 16
            if pixel_rep == 1
              pixels = @stream.decode_all("SS") # Signed short (2 bytes)
            else
              pixels = @stream.decode_all("US") # Unsigned short (2 bytes)
            end
          when 12
            # 12 BIT SIMPLY NOT WORKING YET!
            # This one is a bit more tricky to extract.
            # I havent really given this priority so far as 12 bit image data is rather rare.
            add_msg("Warning: Decoding bit depth 12 is not implemented yet! Please contact the author.")
          else
            raise "Bit depth ["+bit_depth.to_s+"] has not received implementation in this procedure yet. Please contact the author."
        end
      else
        add_msg("Error: DICOM object does not contain the 'Bit Depth' data element (0028,0010).")
      end
      return pixels
    end


    # Modifies existing data element:
    def modify_element(value, pos, options={})
      bin_only = options[:bin]
      # Fetch the VR and old length:
      vr = @types[pos]
      old_length = @lengths[pos]
      # Encode binary (if a binary is not provided):
      if bin_only == true
        # Data already encoded.
        bin = value
        value = nil
      else
        if vr != "UN"
          # Encode:
          bin = encode(value, vr)
        else
          add_msg("Error. Unable to encode data element value of unknown type (Value Representation)!")
        end
      end
      # Update the arrays with this new information:
      if bin
        # Replace array entries for this element:
        #@types[pos] = vr # for the time being there is no logic for updating type.
        @lengths[pos] = bin.length
        @values[pos] = value
        @raw[pos] = bin
        # Update group length (as long as it was not the group length that was modified):
        if @tags[pos][5..8] != "0000"
          change = bin.length - old_length
          update_group_and_parents_length(pos, vr, change, 0)
        end
      else
        add_msg("Binary is nil. Nothing to save.")
      end
    end


    # Prints the selected elements to an ascii text file.
    # The text file will be saved in the folder of the original DICOM file,
    # with the original file name plus a .txt extension.
    def print_file(elements)
      File.open( @file + '.txt', 'w' ) do |output|
        elements.each do | line |
          output.print line + "\n"
        end
      end
    end


    # Prints the selected elements to screen.
    def print_screen(elements)
      elements.each do |element|
        puts element
      end
    end


    # Converts original pixel data values to presentation values.
    # NB: This method is not used at the moment.
    def process_presentation_values(pixel_data, center, width, slope, intercept, min_allowed, max_allowed)
      # Rescale:
      # PixelOutput = slope * pixel_values + intercept
      if intercept != 0 or slope != 1
        pixel_data.collect!{|x| (slope * x) + intercept}
      end
      # Contrast enhancement by black and white thresholding:
      if center and width
        low = center - width/2
        high = center + width/2
        pixel_data.each_index do |i|
          if pixel_data[i] < low
            pixel_data[i] = low
          elsif pixel_data[i] > high
            pixel_data[i] = high
          end
        end
      end
      # Need to introduce an offset?
      min_pixel_value = pixel_data.min
      if min_allowed
        if min_pixel_value < min_allowed
          offset = min_pixel_value.abs
          pixel_data.collect!{|x| x + offset}
        end
      end
      # Downscale pixel range?
      max_pixel_value = pixel_data.max
      if max_allowed
        if max_pixel_value > max_allowed
          factor = (max_pixel_value.to_f/max_allowed.to_f).ceil
          pixel_data.collect!{|x| x / factor}
        end
      end
      return pixel_data
    end


    # Converts original pixel data values to a RMagick image object containing presentation values.
    def process_presentation_values_magick(pixel_data, center, width, slope, intercept, max_allowed, columns, rows)
      # Rescale:
      # PixelOutput = slope * pixel_values + intercept
      if intercept != 0 or slope != 1
        pixel_data.collect!{|x| (slope * x) + intercept}
      end
      # Need to introduce an offset?
      offset = 0
      min_pixel_value = pixel_data.min
      if min_pixel_value < 0
        offset = min_pixel_value.abs
        pixel_data.collect!{|x| x + offset}
      end
      # Downscale pixel range?
      factor = 1
      max_pixel_value = pixel_data.max
      if max_allowed
        if max_pixel_value > max_allowed
          factor = (max_pixel_value.to_f/max_allowed.to_f).ceil
          pixel_data.collect!{|x| x / factor}
        end
      end
      image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
      # Contrast enhancement by black and white thresholding:
      if center and width
        low = (center - width/2 + offset) / factor
        high = (center + width/2 + offset) / factor
        image = image.level(low, high)
      end
      return image
    end


    # Converts original pixel data values to presentation values, using the faster numerical array.
    # NB: This returns a one-dimensional NArray object (i.e. no columns & rows).
    def process_presentation_values_narray(pixel_data, center, width, slope, intercept, min_allowed, max_allowed)
      n_arr = NArray.to_na(pixel_data)
      # Rescale:
      # PixelOutput = slope * pixel_values + intercept
      if intercept != 0 or slope != 1
        n_arr = slope * n_arr + intercept
      end
      # Contrast enhancement by black and white thresholding:
      if center and width
        low = center - width/2
        high = center + width/2
        n_arr[n_arr < low] = low
        n_arr[n_arr > high] = high
      end
      # Need to introduce an offset?
      min_pixel_value = n_arr.min
      if min_allowed
        if min_pixel_value < min_allowed
          offset = min_pixel_value.abs
          n_arr = n_arr + offset
        end
      end
      # Downscale pixel range?
      max_pixel_value = n_arr.max
      if max_allowed
        if max_pixel_value > max_allowed
          factor = (max_pixel_value.to_f/max_allowed.to_f).ceil
          n_arr = n_arr / factor
        end
      end
      return n_arr
    end


    # Returns one or more RMagick image objects from the binary string pixel data,
    # performing decompression of data if necessary.
    def read_image_magick(pos, columns, rows, frames, options={})
      if pos == false or columns == false or rows == false
        add_msg("Error: Method read_image_magick does not have enough data available to build an image object. Returning false.")
        return false
      end
      unless @compression
        # Non-compressed, just return the array contained on the particular element:
        pixel_data = get_pixels(pos)
        # Process pixel data for presentation according to the information in the DICOM file:
        center = get_value("0028,1050", :silent => true)
        width = get_value("0028,1051", :silent => true)
        intercept = get_value("0028,1052", :silent => true) || 0
        slope = get_value("0028,1053", :silent => true) || 1
        center = center.to_i if center
        width = width.to_i if width
        intercept = intercept.to_i
        slope = slope.to_i
        # What tools will be used to process the pixel presentation values?
        if options[:narray]
          # Use numerical array (fast):
          pixel_data = process_presentation_values_narray(pixel_data, center, width, slope, intercept, 0, Magick::QuantumRange).to_a
          image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
        else
          # Use a combination of ruby array and RMagick processing:
          image = process_presentation_values_magick(pixel_data, center, width, slope, intercept, Magick::QuantumRange, columns, rows)
        end
        return image
      else
        # Image data is compressed, we will attempt to deflate it using RMagick (ImageMagick):
        begin
          image = Magick::Image.from_blob(@raw[pos])
          return image
        rescue
          add_msg("RMagick did not succeed in decoding the compressed image data. Returning false.")
          return false
        end
      end
    end


    # Sets the modality variable of the current DICOM object, by querying the library with the object's SOP Class UID.
    def set_modality
      value = get_value("0008,0016", :silent => true)
      if value == false
        @modality = "Not specified"
      else
        modality = LIBRARY.get_uid(value.rstrip)
        @modality = modality
      end
    end


    # Handles the creation of a DWrite object, and returns this object to the calling method.
    def set_write_object(file_name = nil, transfer_syntax = nil)
      unless transfer_syntax
        transfer_syntax = get_value("0002,0010", :silent => true)
        transfer_syntax = "1.2.840.10008.1.2" if not transfer_syntax # Default is implicit, little endian
      end
      w = DWrite.new(file_name, :sys_endian => @sys_endian, :transfer_syntax => transfer_syntax)
      w.tags = @tags
      w.types = @types
      w.lengths = @lengths
      w.raw = @raw
      w.rest_endian = @file_endian
      w.rest_explicit = @explicit
      return w
    end


    # Updates the group length value when a data element has been updated, created or removed.
    # If the tag is part of a sequence/item, and its parent have length values, these parents' lengths are also updated.
    # The variable value_change_length holds the change in value length for the updated data element.
    # (value_change_length should be positive when a data element is removed - it will only be negative when editing an element to a shorter value)
    # The variable existance is -1 if data element has been removed, +1 if element has been added and 0 if it has been updated.
    # There is some repetition of code in this method, so there is possible a potential to clean it up somewhat.
    def update_group_and_parents_length(pos, type, value_change_length, existance)
      update_positions = Array.new
      # Is this a tag with parents?
      if @levels[pos] > 0
        parent_positions = parents(pos)
        parent_positions.each do |parent|
          # If the parent has a length value, then it must be added to our list of tags that will have its length updated:
          update_positions << parent if @lengths[parent] > 0
        end
      end
      # Check for a corresponding group length tag:
      gl_pos = find_group_length(pos)
      # Join the arrays if group length tag(s) were actually discovered (Operator | can be used here for simplicity, but seems to be not working in Ruby 1.8)
      if gl_pos
        gl_pos.each do |gl|
          update_positions << gl
        end
      end
      existance = 0 unless existance
      # If group length(s)/parent(s) to be updated exists, calculate change:
      if update_positions
        values = Array.new
        if existance == 0
          # Element has only been updated, so we only need to think about value value_change_length:
          update_positions.each do |up|
            # If we have a group length, value will be changed, if it is a sequence/item, length will be changed:
            if @tags[up][5..8] == "0000"
              values << @values[up] + value_change_length
            else
              values << @lengths[up] + change
            end
          end
        else
          # Element has either been created or removed. This means we need to calculate the length of its other parts.
          if @explicit
            # In the explicit scenario it is slightly complex to determine this value:
            element_length = 0
            # VR?:
            unless @tags[pos] == "FFFE,E000" or @tags[pos] == "FFFE,E00D" or @tags[pos] == "FFFE,E0DD"
              element_length += 2
            end
            # Length value:
            case @types[pos]
              when "OB","OW","SQ","UN"
                if pos > @tags.index("7FE0,0010").to_i and @tags.index("7FE0,0010").to_i != 0
                  element_length += 4
                else
                  element_length += 6
                end
              when "()"
                element_length += 4
              else
                element_length += 2
            end
          else
            # In the implicit scenario it is easier:
            element_length = 4
          end
          # Update group length for creation/deletion scenario:
          change = (4 + element_length + value_change_length) * existance
          update_positions.each do |up|
            # If we have a group length, value will be changed, if it is a sequence/item, length will be changed:
            if @tags[up][5..8] == "0000"
              values << @values[up] + change
            else
              values << @lengths[up] + change
            end
          end
        end
        # Write the new Group Length(s)/parent(s) value(s):
        update_positions.each_index do |i|
          # If we have a group length, value will be changed, if it is a sequence/item, length will be changed:
          if @tags[update_positions[i]][5..8] == "0000"
            # Encode the new value to binary:
            bin = encode(values[i], "UL")
            # Update arrays:
            @values[update_positions[i]] = values[i]
            @raw[update_positions[i]] = bin
          else
            @lengths[update_positions[i]] = values[i]
          end
        end
      end
    end # of update_group_and_parents_length


  end # of class
end # of module
