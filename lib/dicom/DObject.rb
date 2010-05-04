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

    attr_reader :errors, :modality, :parent, :read_success, :segments, :stream, :write_success

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
        @signature = r.signature
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
    def write(file_name, options={})
      w = set_write_object(file_name, options)
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
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    # The returned array does not carry the dimensions of the pixel data: It will be a one dimensional array (vector).
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    # :narray => true  - Performs the rescale process with NArray instead of Ruby Array, which is faster.
    def get_image(options={})
      pixel_data_element = self[PIXEL_TAG]
      if pixel_data_element
        # For now we only support returning pixel data if the image is located in a single pixel data element:
        if pixel_data_element.is_a?(DataElement)
          pixels = decode_pixels(pixel_data_element.bin)
          # Remap the image from pixel values to presentation values if the user has requested this:
          if options[:rescale]
            if options[:narray]
              # Use numerical array (faster):
              pixels = process_presentation_values_narray(pixels, -65535, 65535).to_a
            else
              # Use standard Ruby array (slower):
              pixels = process_presentation_values(pixels, -65535, 65535)
            end
          end
        else
          add_msg("Warning: Method get_image() does not currently support returning pixel data from encapsulated images.")
          pixels = false
        end
      else
        pixels = nil
      end
      return pixels
    end


    # Returns a 3d NArray object where the array dimensions corresponds to [frames, columns, rows].
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    # To call this method the user needs to loaded the NArray library in advance (require 'narray').
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    def get_image_narray(options={})
      color = (self["0028,0004"].is_a?(DataElement) == true ? self["0028,0004"].value : "")
      pixel_data_element = self[PIXEL_TAG]
      if pixel_data_element
        # For now we only support returning pixel data if the image is located in a single pixel data element:
        if pixel_data_element.is_a?(DataElement)
          if color.upcase.include?("MONOCHROME")
            # Creating a NArray object using int to make sure we have the necessary range for our numbers:
            rows, columns, frames = image_properties
            pixel_data = NArray.int(frames,columns,rows)
            pixel_frame = NArray.int(columns,rows)
            pixels = decode_pixels(pixel_data_element.bin)
            # Read frame by frame:
            frames.times do |i|
              (columns*rows).times do |j|
                pixel_frame[j] = pixels[j+i*columns*rows]
              end
              pixel_data[i, true, true] = pixel_frame
            end
            # Remap the image from pixel values to presentation values if the user has requested this:
            pixels = process_presentation_values_narray(pixel_data, -65535, 65535) if options[:rescale]
          else
            add_msg("Warning: Either Photomtetric Interpretation is missing, or the DICOM object contains pixel data with colors, which is unsupported as of yet.")
            pixels = false
          end
        else
          add_msg("Warning: Method get_image_narray() does not currently support returning pixel data from encapsulated images.")
          pixels = false
        end
      else
        pixels = nil
      end
      return pixels
    end


    # Returns a RMagick image, built from the pixel data and image information in the DICOM object.
    # Returns nil if no pixel data is present, and false if it fails to retrieve pixel data which is present.
    # To call this method the user needs to have loaded the ImageMagick library in advance (require 'RMagick').
    # Options:
    # :rescale => true  - Return processed, rescaled presentation values instead of the original, full pixel range.
    # :narray => true  - Use NArray when rescaling pixel values (faster than using RMagick/Ruby array).
    def get_image_magick(options={})
      color = (self["0028,0004"].is_a?(DataElement) == true ? self["0028,0004"].value : "")
      pixel_data_element = self[PIXEL_TAG]
      if pixel_data_element
        # For now we only support returning pixel data if the image is located in a single pixel data element:
        if pixel_data_element.is_a?(DataElement)
          if color.upcase.include?("MONOCHROME")
            # Creating a NArray object using int to make sure we have the necessary range for our numbers:
            rows, columns, frames = image_properties
            pixels = decode_pixels(pixel_data_element.bin)
            image = read_image_magick(pixels, columns, rows, frames, options)
            add_msg("Warning: Unfortunately, this method only supports reading the first image frame for 3D pixel data as of now.") if frames > 1
          else
            add_msg("Warning: Either Photomtetric Interpretation is missing, or the DICOM object contains pixel data with colors, which is unsupported as of yet.")
            image = false
          end
        else
          add_msg("Warning: Method get_image_magick() does not currently support returning pixel data from encapsulated images.")
          image = false
        end
      else
        image = nil
      end
      return image
    end


    # Dumps the binary content of the Pixel Data element to file.
    def image_to_file(file)
      pixel_element = self[PIXEL_TAG]
      pixel_data = Array.new
      if pixel_element
        # Pixel data may be a single binary string, or located in several item elements:
        if pixel_element.is_a?(DataElement)
          pixel_data << pixel_element.bin
        else
          pixel_items = pixel_element.child_array.first.child_array
          pixel_items.each do |item|
            pixel_data << item.bin
          end
        end
        pixel_data.each_index do |i|
          if pixel_data.length == 1
            f = File.new(file, "wb")
          else
            f = File.new("#{file}_#{i}", "wb")
          end
          f.write(pixel_data[i])
          f.close
        end
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


    # Returns data regarding the geometrical properties of the image(s): rows, columns & number of frames.
    def image_properties
      row_element = self["0028,0010"]
      column_element = self["0028,0011"]
      frames = (self["0028,0008"].is_a?(DataElement) == true ? self["0028,0008"].value.to_i : 1)
      if row_element and column_element
        return row_element.value, column_element.value, frames
      else
        raise "The Data Element which specifies Rows is missing. Unable to gather enough information to constuct an image." unless row_element
        raise "The Data Element which specifies Columns is missing. Unable to gather enough information to constuct an image." unless column_element
      end
    end


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


    # Removes all sequences from the DObject.
    def remove_sequences
      @tags.each_value do |element|
        remove(element.tag) if element.is_a?(Sequence)
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

=begin
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
=end

    # Unpacks and returns pixel values in an Array from the specified binary string.
    def decode_pixels(bin)
      pixels = false
      # We need to know what kind of bith depth and integer type the pixel data is saved with:
      bit_depth_element = self["0028,0100"]
      pixel_representation_element = self["0028,0103"]
      if bit_depth_element and pixel_representation_element
        # Load the binary pixel data to the Stream instance:
        @stream.set_string(bin)
        # Number of bytes used per pixel will determine how to unpack this:
        case bit_depth_element.value.to_i
          when 8
            pixels = @stream.decode_all("BY") # Byte/Character/Fixnum (1 byte)
          when 16
            if pixel_representation_element.value.to_i == 1
              pixels = @stream.decode_all("SS") # Signed short (2 bytes)
            else
              pixels = @stream.decode_all("US") # Unsigned short (2 bytes)
            end
          when 12
            # 12 BIT SIMPLY NOT WORKING YET!
            # This one is a bit tricky to extract. I havent really given this priority so far as 12 bit image data is rather rare.
            raise "Decoding bit depth 12 is not implemented yet! Please contact the author (or edit the source code)."
          else
            raise "The Bit Depth #{bit_depth} has not received implementation in this procedure yet. Please contact the author (or edit the source code)."
        end
      else
        raise "The Data Element which specifies Bit Depth is missing. Unable to decode pixel data." unless bit_depth_element
        raise "The Data Element which specifies Pixel Representation is missing. Unable to decode pixel data." unless pixel_representation_element
      end
      return pixels
    end


    # Converts original pixel data values to presentation values.
    def process_presentation_values(pixel_data, min_allowed, max_allowed)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
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
    def process_presentation_values_magick(pixel_data, max_allowed, columns, rows)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
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
    def process_presentation_values_narray(pixel_data, min_allowed, max_allowed)
      # Process pixel data for presentation according to the image information in the DICOM object:
      center, width, intercept, slope = window_level_values
      # Need to convert to NArray?
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
    # Reading compressed data has been removed for now as it never seemed to work on any of the samples.
    # Tested with RMagick and something like: image = Magick::Image.from_blob(element.bin)
    def read_image_magick(pixel_data, columns, rows, frames, options={})
      # Remap the image from pixel values to presentation values if the user has requested this:
      if options[:rescale] == true
        # What tools will be used to process the pixel presentation values?
        if options[:narray] == true
          # Use numerical array (fast):
          pixel_data = process_presentation_values_narray(pixel_data, 0, Magick::QuantumRange).to_a
          image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
        else
          # Use a combination of ruby array and RMagick processing:
          image = process_presentation_values_magick(pixel_data, Magick::QuantumRange, columns, rows)
        end
      else
        # Load original pixel values to a RMagick object:
        image = Magick::Image.new(columns,rows).import_pixels(0, 0, columns, rows, "I", pixel_data)
      end
      return image
    end


    # Handles the creation of a DWrite object, and returns this object to the calling method.
    def set_write_object(file_name=nil, options={})
      unless options[:transfer_syntax]
        if self["0002,0010"]
          options[:transfer_syntax] = self["0002,0010"].value
        else
          options[:transfer_syntax] = IMPLICIT_LITTLE_ENDIAN
        end
      end
      w = DWrite.new(self, file_name, options)
      w.rest_endian = @file_endian
      w.rest_explicit = @explicit
      return w
    end


    # Gathers and returns the window level values needed to convert the original pixel values to presentation values.
    # If some of these values are missing in the DICOM object, default values are used instead
    # for intercept and slope, while center and width are set to nil. No errors are raised.
    def window_level_values
      center = (self["0028,1050"].is_a?(DataElement) == true ? self["0028,1050"].value.to_i : nil)
      width = (self["0028,1051"].is_a?(DataElement) == true ? self["0028,1051"].value.to_i : nil)
      intercept = (self["0028,1052"].is_a?(DataElement) == true ? self["0028,1052"].value.to_i : 0)
      slope = (self["0028,1053"].is_a?(DataElement) == true ? self["0028,1053"].value.to_i : 1)
      return center, width, intercept, slope
    end


  end # of class
end # of module