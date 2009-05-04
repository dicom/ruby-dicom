#    Copyright 2008-2009 Christoffer Lervåg
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
# -Support for writing complex (hierarchical) DICOM files (basic write support is featured).
# -Full support for compressed image data.
# -Read 12 bit image data correctly.
# -Support for color image data to get_image_narray() and get_image_magick().
# -Complete support for Big endian (basic support is already featured).
# -Complete support for multiple frame image data to NArray and RMagick objects (partial support already featured).
# -Reading of image data in files that contain two different and unrelated images (this problem has been observed with some MR images).

module DICOM

  # Class for handling the DICOM contents:
  class DObject

    attr_reader :read_success, :write_success, :modality, :errors,
                      :names, :tags, :types, :lengths, :values, :raw, :levels

    # Initialize the DObject instance.
    def initialize(file_name=nil, opts={})
      # Process option values, setting defaults for the ones that are not specified:
      @verbose = opts[:verbose]
      @lib =  opts[:lib]  || DLibrary.new
      # Default verbosity is true:
      @verbose = true if @verbose == nil

      # Initialize variables that will be used for the DICOM object:
      @names = Array.new()
      @tags = Array.new()
      @types = Array.new()
      @lengths = Array.new()
      @values = Array.new()
      @raw = Array.new()
      @levels = Array.new()
      # Array that will holde any messages generated while reading the DICOM file:
      @errors = Array.new()
      # Array to keep track of sequences/structure of the dicom elements:
      @sequence = Array.new()
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
      # Check endianness of the system (false if little endian):
      @sys_endian = check_sys_endian()
      # Set format strings for packing/unpacking:
      set_format_strings()

      # If a (valid) file name string is supplied, call the method to read the DICOM file:
      if file_name.is_a?(String) and file_name != ""
        @file = file_name
        read(file_name)
      end
    end # of method initialize


    # Returns a DICOM object by reading the file specified.
    # This is accomplished by initliazing the DRead class, which loads DICOM information to arrays.
    # For the time being, this method is called automatically when initializing the DObject class,
    # but in the future, when write support is added, this method may have to be called manually.
    def read(file_name)
      dcm = DRead.new(file_name, :lib => @lib, :sys_endian => @sys_endian)
      # Store the data to the instance variables if the readout was a success:
      if dcm.success
        @read_success = true
        @names = dcm.names
        @tags = dcm.tags
        @types = dcm.types
        @lengths = dcm.lengths
        @values = dcm.values
        @raw = dcm.raw
        @levels = dcm.levels
        @explicit = dcm.explicit
        @file_endian = dcm.file_endian
        # Set format strings for packing/unpacking:
        set_format_strings(@file_endian)
        # Index of last data element in element arrays:
        @last_index=@names.length-1
        # Update status variables for this object:
        check_properties()
        # Set the modality of the DICOM object:
        set_modality()
      else
        @read_success = false
      end
      # If any messages has been recorded, send these to the message handling method:
      if dcm.msg.size != 0
        add_msg(dcm.msg)
      end
    end


    # Transfers necessary information from the DObject to the DWrite class, which
    # will attempt to write this information to a valid DICOM file.
    def write(file_name)
      w = DWrite.new(file_name, :lib => @lib, :sys_endian => @sys_endian)
      w.tags = @tags
      w.types = @types
      w.lengths = @lengths
      w.raw = @raw
      w.rest_endian = @file_endian
      w.rest_explicit = @explicit
      w.write
      # Write process succesful?
      @write_success = w.success
      # If any messages has been recorded, send these to the message handling method:
      if w.msg.size != 0
        add_msg(w.msg)
      end
    end


    #################################################
    # START OF METHODS FOR READING INFORMATION FROM DICOM OBJECT:#
    #################################################


    # Checks the status of the pixel data that has been read from the DICOM file: whether it exists at all and if its greyscale or color.
    # Modifies instance variable @color if color image is detected and instance variable @compression if no pixel data is detected.
    def check_properties()
      # Check if pixel data is present:
      if @tags.index("7FE0,0010") == nil
        # No pixel data in DICOM file:
        @compression = nil
      else
        @compression = @lib.get_compression(get_value("0002,0010"))
      end
      # Set color variable as true if our object contain a color image:
      col_string = get_value("0028,0004")
      if col_string != false
        if (col_string.include? "RGB") or (col_string.include? "COLOR") or (col_string.include? "COLOUR")
          @color = true
        end
      end
    end


    # Returns image data from the provided element index, performing decompression of data if necessary.
    def read_image_magick(pos, columns, rows)
      if pos == false or columns == false or rows == false
        add_msg("Error: Method read_image_magick() does not have enough data available to build an image object.")
        return false
      end
      if @compression != true
        # Non-compressed, just return the array contained on the particular element:
        image_data=get_pixels(pos)
        image = Magick::Image.new(columns,rows)
        image.import_pixels(0, 0, columns, rows, "I", image_data)
        return image
      else
        # Image data is compressed, we will attempt to unpack it using RMagick (ImageMagick):
        begin
          image = Magick::Image.from_blob(@raw[pos])
          return image
        rescue
          add_msg("RMagick did not succeed in decoding the compressed image data. Returning false.")
          return false
        end
      end
    end


    # Returns a 3d NArray object where the array dimensions are related to [frames, columns, rows].
		# To call this method the user needs to have performed " require 'narray' " in advance.
    def get_image_narray()
      # Does pixel data exist at all in the DICOM object?
      if @compression == nil
        add_msg("It seems pixel data is not present in this DICOM object: returning false.")
        return false
      end
      # No support yet for retrieving compressed data:
      if @compression == true
        add_msg("Reading compressed data to a NArray object not supported yet: returning false.")
        return false
      end
      # No support yet for retrieving color pixel data:
      if @color
        add_msg("Warning: Unpacking color pixel data is not supported yet for this method: returning false.")
        return false
      end
      # Gather information about the dimensions of the image data:
      rows = get_value("0028,0010")
      columns = get_value("0028,0011")
      frames = get_frames()
      image_pos = get_image_pos()
      # Creating a NArray object using int to make sure we have a big enough range for our numbers:
      image = NArray.int(frames,columns,rows)
      image_temp = NArray.int(columns,rows)
      # Handling of image data will depend on whether we have one or more frames,
      # and if it is located in one or more elements:
      if image_pos.size == 1
        # All of the image data is located in one element:
        image_data = get_pixels(image_pos[0])
        #image_data = get_image_data(image_pos[0])
        (0..frames-1).each do |i|
          (0..columns*rows-1).each do |j|
            image_temp[j] = image_data[j+i*columns*rows]
          end
          image[i,true,true] = image_temp
        end
      else
        # Image data is encapsulated in items:
        (0..frames-1).each do |i|
          image_data=get_value(image_pos[i])
          #image_data = get_image_data(image_pos[i])
          (0..columns*rows-1).each do |j|
            image_temp[j] = image_data[j+i*columns*rows]
          end
          image[i,true,true] = image_temp
        end
      end
      # Turn around the images to get the expected orientation when displaying on the screen:
      (0..frames-1).each do |i|
        temp_image=image[i,true,true]
        #Transpose the images:
        temp_image.transpose(1,0)
        #Need to mirror the y-axis:
        (0..temp_image.shape[0]-1).each do |j|
          temp_image[j,0..temp_image.shape[1]-1] = temp_image[j,temp_image.shape[1]-1..0]
        end
        # Put the reoriented image back in the image matrixx:
        image[i,true,true]=temp_image
      end
      return image
    end # of method get_image_narray


    # Returns an array of RMagick image objects, where the size of the array corresponds with the number of frames in the image data.
		# To call this method the user needs to have performed " require 'RMagick' " in advance.
    def get_image_magick()
      # Does pixel data exist at all in the DICOM object?
      if @compression == nil
        add_msg("It seems pixel data is not present in this DICOM object: returning false.")
        return false
      end
      # No support yet for color pixel data:
      if @color
        add_msg("Warning: Unpacking color pixel data is not supported yet for this method: aborting.")
        return false
      end
      # Gather information about the dimensions of the image data:
      rows = get_value("0028,0010")
      columns = get_value("0028,0011")
      frames = get_frames()
      image_pos = get_image_pos()
      # Array that will hold the RMagick image objects, one image object for each frame:
      image_arr = Array.new(frames)
      # Handling of image data will depend on whether we have one or more frames,
      if image_pos.size == 1
        # All of the image data is located in one element:
        #image_data = get_image_data(image_pos[0])
        #(0..frames-1).each do |i|
         # image = Magick::Image.new(columns,rows)
         # image.import_pixels(0, 0, columns, rows, "I", image_data)
         # image_arr[i] = image
        #end
        if frames > 1
          add_msg("Unfortunately, this method only supports reading the first image frame as of now.")
        end
        image = read_image_magick(image_pos[0], columns, rows)
        image_arr[0] = image
        #image_arr[i] = image
      else
        # Image data is encapsulated in items:
        (0..frames-1).each do |i|
          #image_data=get_image_data(image_pos[i])
          #image = Magick::Image.new(columns,rows)
          #image.import_pixels(0, 0, columns, rows, "I", image_data)
          image = read_image_magick(image_pos[i], columns, rows)
          image_arr[i] = image
        end
      end
      return image_arr
    end # of method get_image_magick


    # Returns the number of frames present in the image data in the DICOM file.
    def get_frames()
      frames = get_value("0028,0008")
      if frames == false
        # If the DICOM object does not specify the number of frames explicitly, assume 1 image frame.
        frames = 1
      end
      return frames.to_i
    end


    # Unpacks and returns pixel data from a specified data element array position:
    def get_pixels(pos)
      pixels = false
      # We need to know what kind of bith depth the pixel data is saved with:
      bit_depth = get_value("0028,0100")
      if bit_depth != false
        # Load the binary pixel data:
        bin = get_raw(pos)
        # Number of bytes used per pixel will determine how to unpack this:
        case bit_depth
          when 8
            pixels = bin.unpack(@by) # Byte/Character/Fixnum (1 byte)
          when 16
            pixels = bin.unpack(@us) # Unsigned short (2 bytes)
          when 12
            # 12 BIT SIMPLY NOT WORKING YET!
            # This one is a bit more tricky to extract.
            # I havent really given this priority so far as 12 bit image data is rather rare.
            add_msg("Warning: Bit depth 12 is not working correctly at this time! Please contact the author.")
            #pixels = Array.new(length)
            #(length).times do |i|
              #hex = bin.unpack('H3')
              #hex4 = "0"+hex[0]
              #num = hex[0].unpack('v')
              #data[i] = num
            #end
          else
            raise "Bit depth ["+bit_depth.to_s+"] has not received implementation in this procedure yet. Please contact the author."
        end # of case bit_depth
      else
        add_msg("Error: DICOM object does not contain the 'Bit Depth' data element (0028,0010).")
      end # of if bit_depth ..
      return pixels
    end # of method get_pixels


    # Returns the index(es) of the element(s) that contain image data.
    def get_image_pos()
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
            frames = get_frames()
            if frames != false  # note: function get_frames will never return false
              if late_item_pos.size == frames.to_i+1
                return late_item_pos[1..late_item_pos.size-1]
              else
                add_msg("Warning: Unexpected behaviour in DICOM file for method get_image_pos(). Expected number of image data items not equal to number of frames+1, returning false.")
                return false
              end
            else
              add_msg("Warning: 'Number of Frames' data element not found. Method get_image_pos() will return false.")
              return false
            end
          end
        end
      end
    end # of method get_image_pos


    # Returns an array of the index(es) of the element(s) in the DICOM file that match the supplied element position, tag or name.
    # If no match is found, the method will return false.
    # Additional options:
    # :array => myArray - tells the method to search for matches in this specific array of positions instead of searching
    #                                  through the entire DICOM object. If myArray equals false, the method will return false.
    # :partial => true - get_pos will not only search for exact matches, but will search the names and tags arrays for
    #                             strings that contain the given search string.
    def get_pos(query, opts={})
      # Optional keywords:
      keyword_array = opts[:array]
      keyword_partial = opts[:partial]
      indexes = Array.new()
      # For convenience, allow query to be a one-element array (its value will be extracted):
      if query.is_a?(Array)
        if query.length > 1 or query.length == 0
          add_msg("Invalid array length supplied to method get_pos.")
          return false
        else
          query = query[0]
        end
      end
      if keyword_array == false
        # If the supplied array option equals false, it signals that the user tries to search for an element
        # in an invalid position, and as such, this method will also return false:
        add_msg("Warning: Attempted to call get_pos() with query #{query}, but since keyword :array is false I will return false.")
        indexes = false
      else
        # Check if query is a number (some methods want to have the ability to call get_pos() with a number):
        if query.is_a?(Integer)
          # Return the position if it is valid:
          indexes = [query] if query >= 0 and query < @names.length
        elsif query.is_a?(String)
          # Either use the supplied array, or search the entire DICOM object:
          if keyword_array.is_a?(Array)
            search_array = keyword_array
          else
            search_array = Array.new(@names.length) {|i| i}
          end
          # Perform search:
          if keyword_partial == true
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
    end # of method get_pos


    # Dumps the binary content of the Pixel Data element to file.
    def image_to_file(file)
      pos = get_image_pos()
      if pos
        if pos.length == 1
          # Pixel data located in one element:
          pixel_data = get_raw(pos[0])
          f = File.new(file, "wb")
          f.write(pixel_data)
          f.close()
        else
          # Pixel data located in several elements:
          pos.each_index do |i|
            pixel_data = get_raw(pos[i])
            f = File.new(file + i.to_s, "wb")
            f.write(pixel_data)
            f.close()
          end
        end
      end # of if pos =...
    end # of method image_to_file


    # Returns the positions of all data elements inside the hierarchy of a sequence or an item.
    # Options:
    # :next_only => true - The method will only search immediately below the specified
    # item or sequence (that is, in the level of parent + 1).
    def children(element, opts={})
      # Process option values, setting defaults for the ones that are not specified:
      opt_next_only = opts[:next_only] || false
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method children(). Returning false.")
      else
        if pos.size > 1
          add_msg("Warning: Method children() does not allow a query which yields multiple array hits. Please use array position instead of tag/name. Returning false.")
        else
          # Proceed to find the value:
          # First we need to establish in which positions to perform the search:
          below_pos = Array.new()
          pos.each do |p|
            parent_level = @levels[p]
            remain_array = @levels[p+1..@levels.size-1]
            extract = true
            remain_array.each_index do |i|
              if (remain_array[i] > parent_level) and (extract == true)
                # If search is targetted at any specific level, we can just add this position:
                if not opt_next_only == true
                  below_pos += [p+1+i]
                else
                  # As search is restricted to parent level + 1, do a test for this:
                  if remain_array[i] == parent_level + 1
                    below_pos += [p+1+i]
                  end
                end
              else
                # If we encounter a position who's level is not deeper than the original level, we can not extract any more values:
                extract = false
              end
            end
          end # of pos.each do..
          value = below_pos if below_pos.size != 0
        end # of if pos.size..else..
      end
      return value
    end # of method below


    # Returns the value (processed raw data) of the requested DICOM data element.
    # Data element may be specified by array position, tag or name.
    # Options:
    # :array => true - Allows the query of the value of a tag that occurs more than one time in the
    #                  DICOM object. Values will be returned in an array with length equal to the number
    #                  of occurances of the tag. If keyword is not specified, the method returns false in this case.
    def get_value(element, opts={})
      opts_array = opts[:array]
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method get_value(). Returning false.")
      else
        if pos.size > 1
          if opts_array == true
            # Retrieve all values into an array:
            value = []
            pos.each do |i|
              value << @values[i]
            end
          else
            add_msg("Warning: Method get_value() does not allow a query which yields multiple array hits. Please use array position instead of tag/name, or use keyword (:array => true). Returning false.")
          end
        else
          value = @values[pos[0]]
        end
      end
      return value
    end # of method get_value


    # Returns the raw data of the requested DICOM data element.
    # Data element may be specified by array position, tag or name.
    # Options:
    # :array => true - Allows the query of the value of a tag that occurs more than one time in the
    #                  DICOM object. Values will be returned in an array with length equal to the number
    #                  of occurances of the tag. If keyword is not specified, the method returns false in this case.
    def get_raw(element, opts={})
      opts_array = opts[:array]
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method get_raw(). Returning false.")
      else
        if pos.size > 1
          if opts_array == true
            # Retrieve all values into an array:
            value = []
            pos.each do |i|
              value << @raw[i]
            end
          else
            add_msg("Warning: Method get_raw() does not allow a query which yields multiple array hits. Please use array position instead of tag/name, or use keyword (:array => true). Returning false.")
          end
        else
          value = @raw[pos[0]]
        end
      end
      return value
    end # of method get_raw


    # Returns the position of (possible) parents of the specified data element in the hierarchy structure of the DICOM object.
    def parents(element)
      value = false
      # Retrieve array position:
      pos = get_pos(element)
      if pos == false
        add_msg("Warning: Invalid data element provided to method parents(). Returning false.")
      else
        if pos.length > 1
          add_msg("Warning: Method parents() does not allow a query which yields multiple array hits. Please use array position instead of tag/name. Returning false.")
        else
          # Proceed to find the value:
          # Get the level of our element:
          level = @levels[pos[0]]
          # Element can obviously only have parents if it is not a top level element:
          unless level == 0
            # Search backwards, and record the position every time we encounter an upwards change in the level number.
            parents = Array.new()
            prev_level = level
            search_arr = @levels[0..pos[0]-1].reverse
            search_arr.each_index do |i|
              if search_arr[i] < prev_level
                parents += [search_arr.length-i-1]
                prev_level = search_arr[i]
              end
            end
            # When the element has several generations of parents, we want its top parent to be first in the returned array:
            parents = parents.reverse
            value = parents if parents.length > 0
          end # of if level == 0
        end # of if pos.length..else..
      end
      return value
    end # of method parents


    ##############################################
    ####### START OF METHODS FOR PRINTING INFORMATION:######
    ##############################################


    # Prints the information of all elements stored in the DICOM object.
    # This method is kept for backwards compatibility.
    # Instead of calling print_all() you may use print(true) for the same functionality.
    def print_all()
      print(true)
    end


    # Prints the information of the specified elements: Index, [hierarchy level, tree visualisation,] tag, name, type, length, value
    # The supplied variable may be a single position, an array of positions, or true - which will make the method print all elements.
    # Optional arguments:
    # :levels => true - method will print the level numbers for each element.
    # :tree => true -   method will print a tree structure for the elements.
    # :file => true -    method will print to file instead of printing to screen.
    def print(pos, opts={})
      # Process option values, setting defaults for the ones that are not specified:
      opt_levels = opts[:levels] || false
      opt_tree = opts[:tree] || false
      opt_file = opts[:file] || false
      # If pos is false, abort, and inform the user:
      if pos == false
        add_msg("Warning: Method print() was supplied false instead of a valid position. Aborting print.")
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
      indices = Array.new()
      levels = Array.new()
      tags = Array.new()
      names = Array.new()
      types = Array.new()
      lengths = Array.new()
      values = Array.new()
      # There may be a more elegant way to do this.
      pos_valid.each do |pos|
        tags += [@tags[pos]]
        levels += [@levels[pos]]
        names += [@names[pos]]
        types += [@types[pos]]
        lengths += [@lengths[pos].to_s]
        values += [@values[pos].to_s]
      end
      # We have collected the data that is to be printed, now we need to do some string manipulation if hierarchy is to be displayed:
      if opt_tree
        # Tree structure requested.
        front_symbol = "| "
        tree_symbol = "|_"
        tags.each_index do |i|
          if levels[i] != 0
            tags[i] = front_symbol*(levels[i]-1) + tree_symbol + tags[i]
          end
        end
      end
      # Extract the string lengths which are needed to make the formatting nice:
      tag_lengths = Array.new()
      name_lengths = Array.new()
      type_lengths = Array.new()
      length_lengths = Array.new()
      names.each_index do |i|
        tag_lengths[i] = tags[i].length
        name_lengths[i] = names[i].length
        type_lengths[i] = types[i].length
        length_lengths[i] = lengths[i].to_s.length
      end
      # To give the printed output a nice format we need to check the string lengths of some of these arrays:
      index_maxL = pos_valid.max.to_s.length
      tag_maxL = tag_lengths.max
      name_maxL = name_lengths.max
      type_maxL = type_lengths.max
      length_maxL = length_lengths.max
      # Construct the strings, one for each line of output, where each line contain the information of one data element:
      elements = Array.new()
      # Start of loop which formats the element data:
      # (This loop is what consumes most of the computing time of this method)
      tags.each_index do |i|
        # Configure empty spaces:
        s = " "
        f0 = " "*(index_maxL-pos_valid[i].to_s.length)
        f2 = " "*(tag_maxL-tags[i].length+1)
        f3 = " "*(name_maxL-names[i].length+1)
        f4 = " "*(type_maxL-types[i].length+1)
        f5 = " "*(length_maxL-lengths[i].to_s.length)
        # Display levels?
        if opt_levels
          lev = levels[i].to_s + s
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
          when "SQ","()"
            value = "(Encapsulated Elements)"
        end
        elements += [f0 + pos_valid[i].to_s + s + lev + s + tags[i] + f2 + names[i] + f3 + types[i] + f4 + f5 + lengths[i].to_s + s + s + value.rstrip]
      end
      # Print to either screen or file, depending on what the user requested:
      if opt_file
        print_file(elements)
      else
        print_screen(elements)
      end # of tags.each do |i|
    end # of method print


    # Prints the key structural properties of the DICOM file.
    def print_properties()
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
        compression = @lib.get_uid(get_value("0002,0010").rstrip)
      else
        compression = "No"
      end
      # Bits per pixel (allocated):
      bits = get_value("0028,0100").to_s
      # Print the file properties:
      puts "Key properties of DICOM object:"
      puts "-------------------------------"
      puts "File:           " + @file
      puts "Modality:       " + @modality.to_s
      puts "Value repr.:    " + explicit
      puts "Byte order:     " + endian
      puts "Pixel data:     " + pixels
      if pixels == "Yes"
        puts "Image:          " + image
        puts "Compression:    " + compression
        puts "Bits per pixel: " + bits
      end
      puts "-------------------------------"
    end # of method print_properties


    ####################################################
    ### START OF METHODS FOR WRITING INFORMATION TO THE DICOM OBJECT:#
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
      end # of if bin.length > 0
    end # of method set_image_file


    # Transfers pixel data from a RMagick object to the pixel data element:
    def set_image_magick(magick_obj)
      # Export the RMagick object to a standard Ruby array of numbers:
      pixel_array = magick_obj.export_pixels(x=0, y=0, columns=magick_obj.columns, rows=magick_obj.rows, map="I")
      # Encode this array using the standard class method:
      set_value(pixel_array, "7FE0,0010", :create => true)
    end


    # Removes an element from the DICOM object:
    def remove(element)
      pos = get_pos(element)
      if pos != false
        if pos.length > 1
          add_msg("Warning: Method remove() does not allow an element query which yields multiple array hits. Please use array position instead of tag/name. Value NOT removed.")
        else
          # Extract first array number:
          pos = pos[0]
          # Update group length:
          if @tags[pos][5..8] != "0000"
            change = @lengths[pos]
            vr = @types[pos]
            update_group_length(pos, vr, change, -1)
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
      else
        add_msg("Warning: The data element #{element} could not be found in the DICOM object. Method remove() has no data element to remove.")
      end
    end


    # Sets the value of a data element by modifying an existing element or creating a new one.
    # If the supplied value is not binary, it will attempt to encode the value to binary itself.
    def set_value(value, element, opts={})
      # Options:
      create = opts[:create] # =false means no element creation
      bin = opts[:bin] # =true means value already encoded
      # Retrieve array position:
      pos = get_pos(element)
      # We do not support changing multiple data elements:
      if pos.is_a?(Array)
        if pos.length > 1
          add_msg("Warning: Method set_value() does not allow an element query which yields multiple array hits. Please use array position instead of tag/name. Value NOT saved.")
          return
        end
      end
      if pos == false and create == false
        # Since user has requested an element shall only be updated, we can not do so as the element position is not valid:
        add_msg("Warning: Invalid data element provided to method set_value(). Value NOT updated.")
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
          tag = @lib.get_tag(element)
          if tag == false
            add_msg("Warning: Method set_value() could not create data element, either because data element name was not recognized in the library, or data element tag is invalid (Expected format of tags is 'GGGG,EEEE').")
          else
            # As we wish to create a new data element, we need to find out where to insert it in the element arrays:
            # We will do this by finding the last array position of the last element that will (alphabetically/numerically) stay in front of this element.
            if @tags.size > 0
              # Search the array:
              index = -1
              quit = false
              while quit != true do
                if index+1 >= @tags.length # We have reached end of array.
                  quit = true
                elsif tag < @tags[index+1] # We are past the correct position.
                  quit = true
                else # Increase index in anticipation of a 'hit'.
                  index += 1
                end
              end # of while
            else
              # We are dealing with an empty DICOM object:
              index = nil
            end
            # The necessary information is gathered; create new data element:
            create_element(value, tag, index, :bin => bin)
          end # of if tag ==..else..
        end # of unless pos ==..else..
      end # of if pos ==..and create ==..else..
    end # of method set_value


    ##################################################
    ############## START OF PRIVATE METHODS:################
    ##################################################
    private


    # Adds a warning or error message to the instance array holding messages, and if verbose variable is true, prints the message as well.
    def add_msg(msg)
      if @verbose
        puts msg
      end
      if (msg.is_a? String)
        msg=[msg]
      end
      @errors += msg
    end


    # Checks the endianness of the system. Returns false if little endian, true if big endian.
    def check_sys_endian()
      x = 0xdeadbeef
      endian_type = {
        Array(x).pack("V*") => false, #:little
        Array(x).pack("N*") => true   #:big
      }
      return endian_type[Array(x).pack("L*")]
    end


    # Creates a new data element:
    def create_element(value, tag, last_pos, opts={})
      bin_only = opts[:bin]
      # Fetch the VR:
      info = @lib.get_name_vr(tag)
      vr = info[1]
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
          update_group_length(pos, vr, change, 1)
        end
      else
        add_msg("Binary is nil. Nothing to save.")
      end
    end # of method create_element


    # Encodes a value to binary (used for inserting values to a DICOM object).
    def encode(value, vr)
      # Our value needs to be inside an array to be encoded:
      value = [value] if not value.is_a?(Array)
      # VR will decide how to encode this value:
      case vr
        when "UL"
          bin = value.pack(@ul)
        when "SL"
          bin = value.pack(@sl)
        when "US"
          bin = value.pack(@us)
        when "SS"
          bin = value.pack(@ss)
        when "FL"
          bin = value.pack(@fs)
        when "FD"
          bin = value.pack(@fd)
        when "AT" # (Data element tag: Assume it has the format GGGGEEEE (no comma separation))
          # Encode letter pairs indexes in following order 10 3 2:
          # NB! This may not be encoded correctly on Big Endian files or computers.
          old_format=value[0]
          new_format = old_format[2..3]+old_format[0..1]+old_format[6..7]+old_format[4..5]
          bin = [new_format].pack("H*")

        # We have a number of VRs that are encoded as string:
        when 'AE','AS','CS','DA','DS','DT','IS','LO','LT','PN','SH','ST','TM','UI','UT'
          # In case we are dealing with a number string element, the supplied value might be a number
          # instead of a string, and as such, we convert to string just to make sure this will work nicely:
          value[0] = value[0].to_s
          # Odd/even test (num[0]=1 if num is odd):
          if value[0].length[0] == 1
            # Odd (add a zero byte):
            bin = value.pack('a*') + ["00"].pack("H*")
          else
            # Even:
            bin = value.pack('a*')
          end
        # Image related VR's:
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
                bin = value.pack(@by)
              when 12
                # 12 bit not supported yet!
                add_msg("Encoding 12 bit pixel values not supported yet. Please change the bit depth to 8 or 16 bits.")
              when 16
                bin = value.pack(@us)
              else
                # Unknown bit depth:
                add_msg("Unknown bit depth #{bit_depth}. No data encoded.")
            end # of case bit_depth
          end # of if bit_depth..else..
        else # Unsupported VR:
          add_msg("Element type #{vr} does not have a dedicated encoding option assigned. Please contact author.")
      end # of case vr
      return bin
    end # of method encode

    # Modifies existing data element:
    def modify_element(value, pos, opts={})
      bin_only = opts[:bin]
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
          update_group_length(pos, vr, change, 0)
        end
      else
        add_msg("Binary is nil. Nothing to save.")
      end
    end # of method modify_element


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


    # Sets the modality variable of the current DICOM object, by querying the library with the object's SOP Class UID.
    def set_modality()
      value = get_value("0008,0016")
      if value == false
        @modality = "Not specified"
      else
        modality = @lib.get_uid(value.rstrip)
        @modality = modality
      end
    end


    # Sets the format strings that will be used for packing/unpacking numbers depending on endianness of file/system.
    def set_format_strings(file_endian=@file_endian)
      if @file_endian == @sys_endian
        # System endian equals file endian:
        # Native byte order.
        @by = "C*" # Byte (1 byte)
        @us = "S*" # Unsigned short (2 bytes)
        @ss = "s*" # Signed short (2 bytes)
        @ul = "I*" # Unsigned long (4 bytes)
        @sl = "l*" # Signed long (4 bytes)
        @fs = "e*" # Floating point single (4 bytes)
        @fd = "E*" # Floating point double ( 8 bytes)
      else
        # System endian not equal to file endian:
        # Network byte order.
        @by = "C*"
        @us = "n*"
        @ss = "n*" # Not correct (gives US)
        @ul = "N*"
        @sl = "N*" # Not correct (gives UL)
        @fs = "g*"
        @fd = "G*"
      end
    end


    # Updates the group length value when a data element has been updated, created or removed:
    # The variable change holds the change in value length for the updated data element.
    # (Change should be positive when a data element is removed - it will only be negative when editing an element to a shorter value)
    # The variable existance is -1 if data element has been removed, +1 if element has been added and 0 if it has been updated.
    # (Perhaps in the future this functionality might be moved to the DWrite class, it might give an easier implementation)
    def update_group_length(pos, type, change, existance)
      # Find position of relevant group length (if it exists):
      gl_pos = @tags.index(@tags[pos][0..4] + "0000")
      existance = 0 if existance == nil
      # If it exists, calculate change:
      if gl_pos
        if existance == 0
          # Element has only been updated, so we only need to think about value change:
          value = @values[gl_pos] + change
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
            end # of case
          else
            # In the implicit scenario it is easier:
            element_length = 4
          end
          # Update group length for creation/deletion scenario:
          change = (4 + element_length + change) * existance
          value = @values[gl_pos] + change
        end
        # Write the new Group Length value:
        # Encode the new value to binary:
        bin = encode(value, "UL")
        # Update arrays:
        @values[gl_pos] = value
        @raw[gl_pos] = bin
      end # of if gl_pos
    end # of method update_group_length


  end # End of class
end # End of module
