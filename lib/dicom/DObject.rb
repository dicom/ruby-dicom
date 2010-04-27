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
# -The retrieve file network functionality (get_image in DClient class) has not been tested.
# -Make the networking code more intelligent in its handling of unexpected network communication.
# -Full support for compressed image data.
# -Read/Write 12 bit image data.
# -Support for color image data.
# -Complete support for Big endian (Everything but signed short and signed long has been implemented).
# -Complete support for multiple frame image data to NArray and RMagick objects (partial support already featured).
# -Image handling does not take into consideration DICOM tags which specify orientation, samples per pixel and photometric interpretation.
# -More robust and flexible options for reorienting extracted pixel arrays?
# -Could the usage of arrays in DObject be replaced with something better, or at least improved upon, to give cleaner code and more efficient execution?
# -A curious observation: Instantiating the DLibrary class is exceptionally slow on my Ruby 1.9.1 install: 0.4 seconds versus ~0.01 seconds on my Ruby 1.8.7 install!

module DICOM

  # Class for interacting with the DICOM object.
  class DObject < SuperItem

    attr_reader :errors, :modality, :parent, :read_success, :segments, :write_success

    # Initialize the DObject instance.
    # Parameters:
    # string
    # options
    #
    # Options:
    # :bin
    # :segment_size
    # :syntax
    # :verbose
    def initialize(string=nil, options={})
      # Process option values, setting defaults for the ones that are not specified:
      # Default verbosity is true if verbosity hasn't been specified (nil):
      @verbose = (options[:verbose] == false ? false : true)
      # Initialization of variables that DObject share with other parent elements:
      initialize_parent
      # Messages (errors, warnings or notices) will be accumulated in an array:
      @errors = Array.new
      # Structural information (default values):
      @compression = false
      @color = false
      @explicit = true
      @file_endian = false
      # Control variables:
      @read_success = false
      # Initialize a Stream instance which is used for encoding/decoding:
      @stream = Stream.new(nil, @file_endian, @explicit)
      # The DObject instance is the top of the hierarchy and unlike other elements it has no parent:
      @parent = nil
      # For convenience, call the read method if a string has been supplied:
      if string.is_a?(String) and string != ""
        @file = string unless options[:bin]
        read(string, options)
      end
    end


    # Returns a DICOM object by reading the file specified.
    # This is accomplished by initliazing the DRead class, which loads DICOM information to arrays.
    # For the time being, this method is called automatically when initializing the DObject class,
    # but in the future, when write support is added, this method may have to be called manually.
    def read(string, options={})
      r = DRead.new(self, string, options)
      # If reading failed, we will make another attempt at reading the file while forcing explicit (little endian) decoding.
      # This will help for some rare cases where the DICOM file is saved (erroneously, Im sure) with explicit encoding without specifying the transfer syntax tag.
      unless r.success
        r_explicit = DRead.new(self, string, :bin => options[:bin], :syntax => EXPLICIT_LITTLE_ENDIAN)
        # Only extract information from this new attempt if it was successful:
        r = r_explicit if r_explicit.success
      end
      # Store the data to the instance variables if the readout was a success:
      if r.success
        @read_success = true
        # Update instance variables based on the properties of the DICOM object:
        @explicit = r.explicit
        @file_endian = r.file_endian
        @stream.explicit = @explicit
        @stream.set_endian(@file_endian)
      else
        @read_success = false
      end
      # If any messages has been recorded, send these to the message handling method:
      add_msg(r.msg) if r.msg.length > 0
    end


    # Passes the DObject to the DWrite class, which recursively traverses the Data Element
    # structure and encodes a proper binary string, which is then written to the specified file.
    def write(file_name, transfer_syntax=nil)
      w = set_write_object(file_name, transfer_syntax)
      w.write
      # Write process succesful?
      @write_success = w.success
      # If any messages has been recorded, send these to the message handling method:
      add_msg(w.msg) if w.msg.length > 0
    end


    # Encodes the DICOM object into a series of binary string segments with a specified maximum length.
    def encode_segments(max_size)
      w = set_write_object
      w.encode_segments(max_size)
      @segments = w.segments
      # Write process succesful?
      @write_success = w.success
      # If any messages has been recorded, send these to the message handling method:
      add_msg(w.msg) if w.msg.length > 0
    end


    #################################################
    # START OF METHODS FOR READING INFORMATION FROM DICOM OBJECT:
    #################################################


    # Returns the image pixel data in a standard Ruby array.
    # Returns false if it fails to retrieve image data.
    # The array does not carry the dimensions of the pixel data, it will be a one dimensional array (vector).
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    def get_image(options={})
      pixel_data = false
      pixel_element_pos = get_image_pos
      # A hack for the special case (some MR files), where two images are stored (one is a smaller thumbnail image):
      pixel_element_pos = [pixel_element_pos.last] if pixel_element_pos.length > 1 and get_value("0028,0011", :array => true).length > 1
      # For now we only support returning pixel data if the image is located in a single pixel data element:
      if pixel_element_pos.length == 1
        # All of the pixel data is located in one element:
        pixel_data = get_pixels(pixel_element_pos[0])
      else
        add_msg("Warning: Method get_image() does not currently support returning pixel data from encapsulated images!")
      end
      # Remap the image from pixel values to presentation values if the user has requested this:
      if options[:rescale] == true and pixel_data
        # Process pixel data for presentation according to the image information in the DICOM object:
        center, width, intercept, slope = window_level_values
        if options[:narray] == true
          # Use numerical array (faster):
          pixel_data = process_presentation_values_narray(pixel_data, center, width, slope, intercept, -65535, 65535).to_a
        else
          # Use standard Ruby array (slower):
          pixel_data = process_presentation_values(pixel_data, center, width, slope, intercept, -65535, 65535)
        end
      end
      return pixel_data
    end


    # Returns a 3d NArray object where the array dimensions corresponds to [frames, columns, rows].
    # Returns false if it fails to retrieve image data.
    # To call this method the user needs to loaded the NArray library in advance (require 'narray').
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    def get_image_narray(options={})
      # Are we able to make a pixel array?
      if @compression == nil
        add_msg("It seems pixel data is not present in this DICOM object.")
        return false
      elsif @compression == true
        add_msg("Reading compressed data to a NArray object not supported yet.")
        return false
      elsif @color
        add_msg("Warning: Unpacking color pixel data is not supported yet for this method.")
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
      # Remap the image from pixel values to presentation values if the user has requested this:
      if options[:rescale] == true
        # Process pixel data for presentation according to the image information in the DICOM object:
        center, width, intercept, slope = window_level_values
        pixel_data = process_presentation_values_narray(pixel_data, center, width, slope, intercept, -65535, 65535)
      end
      return pixel_data
    end # of get_image_narray


    # Returns an array of RMagick image objects, where the size of the array corresponds to the number of frames in the image data.
    # Returns false if it fails to retrieve image data.
    # To call this method the user needs to have loaded the ImageMagick library in advance (require 'RMagick').
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    # :narray => true  - Use NArray when rescaling pixel values (faster than using RMagick/Ruby array).
    def get_image_magick(options={})
      # Are we able to make an image?
      if @compression == nil
        add_msg("Notice: It seems pixel data is not present in this DICOM object.")
        return false
      elsif @color
        add_msg("Warning: Unpacking color pixel data is not supported yet for this method.")
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
      if pixel_element_pos.length == 1
        # All of the pixel data is located in one data element:
        if frames > 1
          add_msg("Unfortunately, this method only supports reading the first image frame for 3D pixel data as of now.")
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


    # Dumps the binary content of the Pixel Data element to file.
    def image_to_file(file)
      pos = get_image_pos
      # Pixel data may be located in several elements:
      pos.each_index do |i|
        pixel_data = get_bin(pos[i])
        if pos.length == 1
          f = File.new(file, "wb")
        else
          f = File.new(file + i.to_s, "wb")
        end
        f.write(pixel_data)
        f.close
      end
    end


    ##############################################
    ####### START OF METHODS FOR PRINTING INFORMATION:######
    ##############################################


    # Gathers key information about the DICOM object in a string array.
    # This array can be printed to screen (default), printed to a file specified by the user or simply returned to the caller.
    def information
      sys_info = Array.new
      info = Array.new
      # Version of Ruby DICOM used:
      sys_info << "Ruby DICOM version:   #{VERSION}"
      # System endian:
      if CPU_ENDIAN
        cpu = "Big Endian"
      else
        cpu = "Little Endian"
      end
      sys_info << "Byte Order (CPU):     #{cpu}"
      # File path/name:
      info << "File:                 #{@file}"
      # Modality:
      sop_class_uid = self["0008,0016"]
      if sop_class_uid
        modality = LIBRARY.get_uid(sop_class_uid.value)
      else
        modality = "SOP Class not specified!"
      end
      info << "Modality:             #{modality}"
      # Meta header presence (Simply check for the presence of the transfer syntax data element), VR and byte order:
      transfer_syntax = self["0002,0010"]
      if transfer_syntax
        syntax_validity, explicit, endian = LIBRARY.process_transfer_syntax(transfer_syntax.value)
        if syntax_validity
          meta_comment = ""
          explicit_comment = ""
          encoding_comment = ""
        else
          meta_comment = " (But unknown/invalid transfer syntax: #{transfer_syntax})"
          explicit_comment = " (Assumed)"
          encoding_comment = " (Assumed)"
        end
        if explicit
          explicitness = "Explicit"
        else
          explicitness = "Implicit"
        end
        if endian
          encoding = "Big Endian"
        else
          encoding = "Little Endian"
        end
      else
        meta = "No"
        explicitness = (@explicit == true ? "Explicit" : "Implicit")
        encoding = (@file_endian == true ? "Big Endian" : "Little Endian")
        explicit_comment = " (Assumed)"
        encoding_comment = " (Assumed)"
      end
      meta = "Yes#{meta_comment}"
      explicit = "#{explicitness}#{explicit_comment}"
      encoding = "#{encoding}#{encoding_comment}"
      info << "Value Representation: #{explicit}"
      info << "Byte Order (File):    #{encoding}"
      # Pixel data:
      pixels = self[PIXEL_TAG]
      unless pixels
        info << "Pixel Data:           No"
      else
        info << "Pixel Data:           Yes"
        # Image size:
        cols = self["0028,0011"] || "Columns missing"
        rows = self["0028,0010"] || "Rows missing"
        info << "Image Size:           #{cols.value}*#{rows.value}"
        # Frames:
        frames = self["0028,0008"] || "1"
        if frames != "1"
          # Encapsulated or 3D pixel data:
          if pixels.is_a?(DataElement)
            frames = frames.value + " (3D Pixel Data)"
          else
            frames = frames.value + " (Encapsulated Multiframe Image)"
          end
        end
        info << "Number of frames:     #{frames}"
        # Color:
        colors = self["0028,0004"] || "Not specified"
        info << "Photometry:           #{colors.value}"
        # Compression:
        if transfer_syntax
          compression = LIBRARY.get_compression(transfer_syntax.value)
          if compression
            compression = LIBRARY.get_uid(transfer_syntax.value)
          else
            compression = "No"
          end
        else
          compression = "No (Assumed)"
        end
        info << "Compression:          #{compression}"
        # Pixel bits (allocated):
        bits = self["0028,0100"] || "Not specified"
        info << "Bits per Pixel:       #{bits.value}"
      end
      # Print the DICOM object's key properties:
      separator = "-------------------------------------------"
      puts "\n"
      puts "System Properties:"
      puts separator
      puts sys_info
      puts "\n"
      puts "DICOM Object Properties:"
      puts separator
      puts info
      puts separator
      return info
    end # of information


    ####################################################
    ### START OF METHODS FOR WRITING INFORMATION TO THE DICOM OBJECT:
    ####################################################


    # Writes pixel data from a Ruby Array object to the pixel data element.
    def set_image(pixel_array)
      # Encode this array using the standard class method:
      set_value(pixel_array, "7FE0,0010", :create => true)
    end


    # Reads binary information from file and inserts it in the pixel data element.
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


    # Transfers pixel data from a RMagick object to the pixel data element.
    # NB! Because of rescaling when importing pixel values to a RMagick object, and the possible
    # difference between presentation values and pixel values, the use of set_image_magick() may
    # result in pixel data that is completely different from what is expected.
    # This method should be used only with great care!
    # If value rescaling is wanted, both :min and :max must be set!
    # Options:
    # :max => value  - Pixel values will be rescaled using this as the new maximum value.
    # :min => value  - Pixel values will be rescaled, using this as the new minimum value.
    def set_image_magick(magick_obj, options={})
      # Export the RMagick object to a standard Ruby array of numbers:
      pixel_array = magick_obj.export_pixels(x=0, y=0, columns=magick_obj.columns, rows=magick_obj.rows, map="I")
      # Rescale pixel values?
      if options[:min] and options[:max]
        p_min = pixel_array.min
        p_max = pixel_array.max
        if p_min != options[:min] or p_max != options[:max]
          wanted_range = options[:max] - options[:min]
          factor = wanted_range.to_f/(pixel_array.max - pixel_array.min).to_f
          offset = pixel_array.min - options[:min]
          pixel_array.collect!{|x| ((x*factor)-offset).round}
        end
      end
      # Encode this array using the standard class method:
      set_value(pixel_array, "7FE0,0010", :create => true)
    end


    # Transfers pixel data from a NArray object to the pixel data element.
    # If value rescaling is wanted, both :min and :max must be set!
    # Options:
    # :max => value  - Pixel values will be rescaled using this as the new maximum value.
    # :min => value  - Pixel values will be rescaled, using this as the new minimum value.
    def set_image_narray(narray, options={})
      # Rescale pixel values?
      if options[:min] and options[:max]
        n_min = narray.min
        n_max = narray.max
        if n_min != options[:min] or n_max != options[:max]
          wanted_range = options[:max] - options[:min]
          factor = wanted_range.to_f/(n_max - n_min).to_f
          offset = n_min - options[:min]
          narray = narray*factor-offset
        end
      end
      # Export the NArray object to a standard Ruby array of numbers:
      pixel_array = narray.to_a.flatten!
      # Encode this array using the standard class method:
      set_value(pixel_array, "7FE0,0010", :create => true)
    end


    # Removes all private data elements from the DICOM object.
    def remove_private
      # Private data elemements have a group tag that is odd. This is checked with the private? String method.
      (0...@tags.length).reverse_each do |pos|
        remove(pos) if @tags[pos].private?
      end
    end



    # Following methods are private:
    private



    # Adds a warning or error message to the instance array holding messages, and if verbose variable is true, prints the message as well.
    def add_msg(msg)
      puts msg if @verbose
      @errors << msg
      @errors.flatten
    end


    # Encodes a value to binary (used for inserting values into a DICOM object).
    # Future development: Encoding of tags should be moved to the Stream class,
    # and encoding of image data should be 'outsourced' to a method of its own (encode_image).
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
          bit_depth = get_value("0028,0100", :array => true)[0]
          if bit_depth == false
            # Data element not specified:
            add_msg("Attempted to encode pixel data, but the 'Bit Depth' Data Element (0028,0100) is missing.")
          else
            # 8, 12 or 16 bits per pixel?
            case bit_depth
              when 8
                bin = @stream.encode(value, "BY")
              when 12
                # 12 bit not supported yet!
                add_msg("Encoding 12 bit pixel values not supported yet. Please change the bit depth to 8 or 16 bits.")
              when 16
                # Signed or unsigned integer?
                pixel_representation = get_value("0028,0103", :array => true)[0]
                if pixel_representation
                  if pixel_representation.to_i == 1
                    # Signed integers:
                    bin = @stream.encode(value, "SS")
                  else
                    # Unsigned integers:
                    bin = @stream.encode(value, "US")
                  end
                else
                  add_msg("Attempted to encode pixel data, but the 'Pixel Representation' Data Element (0028,0103) is missing.")
                end
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
    # If a group length tag does not exist, return an empty array.
    def find_group_length(pos)
      positions = Array.new
      group = @tags[pos][0..4]
      # Check if our tag is part of a sequence/item:
      if @levels[pos] > 0
        # Add (possible) group length of top parent:
        parent_positions = parents(pos)
        first_parent_gl_pos = find_group_length(parent_positions.first)
        positions << first_parent_gl_pos.first if first_parent_gl_pos.length > 0
        # Add (possible) group length at current tag's level:
        valid_positions = children(parent_positions.last)
        level_gl_pos = get_pos(group+"0000", :array => valid_positions)
        positions << level_gl_pos.first if level_gl_pos.length > 0
      else
        # We are dealing with a top level tag:
        gl_pos = get_pos(group+"0000")
        # Note: Group level tags of this type may be found elsewhere in the DICOM object inside other
        # sequences/items. We must make sure that such tags are not added to our list:
        gl_pos.each do |gl|
          positions << gl if @levels[gl] == 0
        end
      end
      return positions
    end


    # Unpacks and returns pixel data from a specified data element array position:
    def get_pixels(pos)
      pixels = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth = get_value("0028,0100", :array => true)[0]
      pixel_representation = get_value("0028,0103", :array => true)[0]
      unless bit_depth == false
        # Load the binary pixel data to the Stream instance:
        @stream.set_string(get_bin(pos))
        # Number of bytes used per pixel will determine how to unpack this:
        case bit_depth
          when 8
            pixels = @stream.decode_all("BY") # Byte/Character/Fixnum (1 byte)
          when 16
            if pixel_representation
              if pixel_representation.to_i == 1
                pixels = @stream.decode_all("SS") # Signed short (2 bytes)
              else
                pixels = @stream.decode_all("US") # Unsigned short (2 bytes)
              end
            else
              add_msg("Error: Attempted to decode pixel data, but the 'Pixel Representation' Data Element (0028,0103) is missing.")
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
        add_msg("Error: Attempted to decode pixel data, but the 'Bit Depth' Data Element (0028,0010) is missing.")
      end
      return pixels
    end


    # Converts original pixel data values to presentation values.
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
    # If a Ruby array is supplied, this returns a one-dimensional NArray object (i.e. no columns & rows).
    # If a NArray is supplied, the NArray is returned with its original dimensions.
    def process_presentation_values_narray(pixel_data, center, width, slope, intercept, min_allowed, max_allowed)
      if pixel_data.is_a?(Array)
        n_arr = NArray.to_na(pixel_data)
      else
        n_arr = pixel_data
      end
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
      if columns == false or rows == false
        add_msg("Error: Method read_image_magick() does not have enough data available to build an image object.")
        return false
      end
      unless @compression
        # Non-compressed, just return the array contained on the particular element:
        pixel_data = get_pixels(pos)
        # Remap the image from pixel values to presentation values if the user has requested this:
        if options[:rescale] == true
          # Process pixel data for presentation according to the image information in the DICOM object:
          center, width, intercept, slope = window_level_values
          # What tools will be used to process the pixel presentation values?
          if options[:narray] == true
            # Use numerical array (fast):
            pixel_data = process_presentation_values_narray(pixel_data, center, width, slope, intercept, 0, Magick::QuantumRange).to_a
            image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
          else
            # Use a combination of ruby array and RMagick processing:
            image = process_presentation_values_magick(pixel_data, center, width, slope, intercept, Magick::QuantumRange, columns, rows)
          end
        else
          # Load original pixel values to a RMagick object:
          image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
        end
        return image
      else
        # Image data is compressed, we will attempt to deflate it using RMagick (ImageMagick):
        begin
          image = Magick::Image.from_blob(@bin[pos])
          return image
        rescue
          add_msg("RMagick did not succeed in decoding the compressed image data.")
          return false
        end
      end
    end


    # Handles the creation of a DWrite object, and returns this object to the calling method.
    def set_write_object(file_name=nil, transfer_syntax=nil)
      unless transfer_syntax
        if self["0002,0010"]
          transfer_syntax = self["0002,0010"].value
        else
          transfer_syntax = IMPLICIT_LITTLE_ENDIAN
        end
      end
      w = DWrite.new(self, file_name, :transfer_syntax => transfer_syntax)
      w.rest_endian = @file_endian
      w.rest_explicit = @explicit
      return w
    end


    # Gathers and returns the window level values needed to convert the original pixel values to presentation values.
    def window_level_values
      center = get_value("0028,1050", :silent => true)
      width = get_value("0028,1051", :silent => true)
      intercept = get_value("0028,1052", :silent => true) || 0
      slope = get_value("0028,1053", :silent => true) || 1
      center = center.to_i if center
      width = width.to_i if width
      intercept = intercept.to_i
      slope = slope.to_i
      return center, width, intercept, slope
    end


  end # of class
end # of module