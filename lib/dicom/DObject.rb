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
# -A curious observation: Instantiating the DLibrary class is exceptionally slow on my Ruby 1.9.1 install: 0.4 seconds versus ~0.01 seconds on my Ruby 1.8.7 install!

module DICOM

  # The DObject class holds the DICOM object itself and a variety of methods for manipulating this object.
  #
  class DObject < SuperItem

    attr_reader :errors, :modality, :parent, :read_success, :stream, :write_success

    # Initializes a DObject instance.
    # Parameters:
    # string
    # options
    #
    # Options:
    # :bin
    # :segment_size
    # :syntax
    # :verbose
    #
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
      @stream = Stream.new(nil, @file_endian)
      # The DObject instance is the top of the hierarchy and unlike other elements it has no parent:
      @parent = nil
      # For convenience, call the read method if a string has been supplied:
      if string.is_a?(String) and string != ""
        @file = string unless options[:bin]
        read(string, options)
      end
    end

    # Encodes the DICOM object into a series of binary string segments with a specified maximum length.
    #
    def encode_segments(max_size)
      w = set_write_object
      w.encode_segments(max_size)
      # Write process succesful?
      @write_success = w.success
      # If any messages has been recorded, send these to the message handling method:
      add_msg(w.msg) if w.msg.length > 0
      return w.segments
    end

    # Gathers key information about the DICOM object in a string array.
    # This array can be printed to screen (default), printed to a file specified by the user or simply returned to the caller.
    #
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

    # Returns a DICOM object by reading the file specified.
    # This is accomplished by initliazing the DRead class, which loads DICOM information to arrays.
    # Note:
    # This method is called automatically when initializing the DObject class, and in practice will not be called by users.
    # It should be considered making this a private method.
    #
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
        @stream.set_endian(@file_endian)
      else
        @read_success = false
      end
      # If any messages has been recorded, send these to the message handling method:
      add_msg(r.msg) if r.msg.length > 0
    end

    # Returns the transfer syntax of this DICOM object.
    # If a transfer syntax has not been defined, the default transfer syntax is assumed, and returned.
    #
    def transfer_syntax
      return value("0002,0010") || IMPLICIT_LITTLE_ENDIAN
    end

    # Changes the transfer syntax Data Element of the DICOM object, and performs re-encoding of all
    # number values if a switch of Endianness is implied.
    # NB: This method does not change the nature of the Pixel Data Tag, changing between uncompressed
    # and compressed transfer syntax won't change the pixel data accordingly (this must be taken care of manually).
    #
    def transfer_syntax=(new_syntax)
      valid, new_explicit, new_endian = LIBRARY.process_transfer_syntax(new_syntax)
      if valid
        # Get the old transfer syntax and write the new one to the DICOM object:
        old_syntax = transfer_syntax
        valid, old_explicit, old_endian = LIBRARY.process_transfer_syntax(old_syntax)
        if exists?("0002,0010")
          self["0002,0010"].value = new_syntax
        else
          add(DataElement.new("0002,0010", new_syntax))
        end
        # Update our Stream instance with the new encoding:
        @stream.set_endian(new_endian)
        # Determine if re-encoding is needed:
        if old_endian != new_endian
          # Re-encode all Data Elements with number values:
          encode_children(old_endian)
        else
          add_msg("New transfer syntax #{new_syntax} does not change encoding: No re-encoding needed.")
        end
      else
        raise "Invalid transfer syntax specified: #{new_syntax}"
      end
    end

    # Passes the DObject to the DWrite class, which recursively traverses the Data Element
    # structure and encodes a proper binary string, which is then written to the specified file.
    #
    # === Parameters
    #
    # * <tt>file_name</tt> -- A string which identifies the path & name of the DICOM file which is to be written to disk.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:add_meta</tt> -- Boolean. If set to false, no manipulation of the DICOM object's Meta Group will be performed before the object is written to file.
    #
    def write(file_name, options={})
      insert_missing_meta unless options[:add_meta] == false
      w = set_write_object(file_name, options)
      w.write
      # Write process succesful?
      @write_success = w.success
      # If any messages has been recorded, send these to the message handling method:
      add_msg(w.msg) if w.msg.length > 0
    end


    # Following methods are private:
    private


    # Adds a warning or error message to the instance array holding messages, and if verbose variable is true, prints the message as well.
    #
    def add_msg(msg)
      puts msg if @verbose
      @errors << msg
      @errors.flatten
    end

    # Adds any missing Meta Group (0002,xxxx) data elements to the DICOM object,
    # to ensure that a valid DICOM object will be written to file.
    #
    def insert_missing_meta
      # File Meta Information Version:
      DataElement.new("0002,0001", "0001", :encoded => true, :parent => self) unless exists?("0002,0001")
      # Media Storage SOP Class UID:
      DataElement.new("0002,0002", self.value("0008,0016"), :parent => self) unless exists?("0002,0002")
      # Media Storage SOP Instance UID:
      DataElement.new("0002,0003", self.value("0008,0018"), :parent => self) unless exists?("0002,0003")
      # Transfer Syntax UID:
      DataElement.new("0002,0010", transfer_syntax, :parent => self) unless exists?("0002,0010")
      # Implementation Class UID:
      DataElement.new("0002,0012", UID, :parent => self) unless exists?("0002,0012")
      # Implementation Version Name:
      DataElement.new("0002,0013", NAME, :parent => self) unless exists?("0002,0013")
      # Source Application Entity Title:
      DataElement.new("0002,0016", SOURCE_APP_TITLE, :parent => self) unless exists?("0002,0016")
      # Group length:
      # Although group lengths in general have been retired in DICOM 2008, the meta group seems to have kept its group length.
      # (FIXME: Add group length)
    end

    # Handles the creation of a DWrite object, and returns this object to the calling method.
    #
    def set_write_object(file_name=nil, options={})
      # Set transfer syntax if not already specified externally:
      options[:transfer_syntax] = transfer_syntax unless options[:transfer_syntax]
      w_obj = DWrite.new(self, file_name, options)
      w_obj.rest_endian = @file_endian
      w_obj.rest_explicit = @explicit
      return w_obj
    end

  end # of class
end # of module