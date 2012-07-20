# === TODO:
#
# * The retrieve file network functionality (#get_image in DClient class) has not been tested.
# * Make the networking code more intelligent in its handling of unexpected network communication.
# * Full support for compressed image data.
# * Read/Write 12 bit image data.
# * Full color support (RGB and PALETTE COLOR with #image already implemented).
# * Support for extraction of multiple encapsulated pixel data frames in #pixels and #narray.
# * Image handling currently ignores DICOM tags like Pixel Aspect Ratio, Image Orientation and (to some degree) Photometric Interpretation.
# * More robust and flexible options for reorienting extracted pixel arrays?
# * A curious observation: Creating a DLibrary instance is exceptionally slow on Ruby 1.9.1: 0.4 seconds versus ~0.01 seconds on Ruby 1.8.7!
# * Add these as github issues and remove this list!


#    Copyright 2008-2012 Christoffer Lervag
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
module DICOM

  # The DObject class is the main class for interacting with the DICOM object.
  # Reading from and writing to files is executed from instances of this class.
  #
  # === Inheritance
  #
  # As the DObject class inherits from the ImageItem class, which itself inherits from the Parent class,
  # all ImageItem and Parent methods are also available to instances of DObject.
  #
  class DObject < ImageItem
    include Logging

    # A boolean set as false. This attribute is included to provide consistency with other object types for the internal methods which use it.
    attr_reader :parent
    # A boolean which is set as true if a DICOM file has been successfully read & parsed from a file (or binary string).
    attr_accessor :read_success
    # The Stream instance associated with this DObject instance (this attribute is mostly used internally).
    attr_reader :stream
    # A boolean which is set as true if a DObject instance has been successfully written to file (or successfully encoded).
    attr_reader :write_success

    alias_method :read?, :read_success
    alias_method :written?, :write_success

    # Creates a DObject instance by downloading a DICOM file
    # specified by a hyperlink, and parsing the retrieved file.
    #
    # === Restrictions
    #
    # * Highly experimental and un-tested!
    # * Designed for HTTP protocol only.
    # * Whether this method should be included or removed from ruby-dicom is up for debate.
    #
    # === Parameters
    #
    # * <tt>link</tt> -- A hyperlink string which specifies remote location of the DICOM file to be loaded.
    #
    def self.get(link)
      raise ArgumentError, "Invalid argument 'link'. Expected String, got #{link.class}." unless link.is_a?(String)
      raise ArgumentError, "Invalid argument 'link'. Expected a string starting with 'http', got #{link}." unless link.index('http') == 0
      require 'open-uri'
      bin = nil
      file = nil
      # Try to open the remote file using open-uri:
      retrials = 0
      begin
        file = open(link, 'rb') # binary encoding (ASCII-8BIT)
      rescue Exception => e
        if retrials > 3
          retrials = 0
          raise "Unable to retrieve the file. File does not exist?"
        else
          logger.warn("Exception in ruby-dicom when loading a dicom file from: #{file}")
          logger.debug("Retrying... #{retrials}")
          retrials += 1
          retry
        end
      end
      bin = File.open(file, "rb") { |f| f.read }
      # Parse the file contents and create the DICOM object:
      if bin
        dcm = self.parse(bin)
      else
        dcm = self.new
        dcm.read_success = false
      end
      return dcm
    end

    # Creates a DObject instance by parsing an encoded binary DICOM string.
    #
    # === Parameters
    #
    # * <tt>string</tt> -- An encoded binary string containing DICOM information.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:no_meta</tt> -- Boolean. If true, the parsing algorithm is instructed that the binary DICOM string contains no meta header.
    # * <tt>:syntax</tt> -- String. If a syntax string is specified, the parsing algorithm will be forced to use this transfer syntax when decoding the binary string.
    #
    # === Examples
    #
    #   # Parse a DICOM file that has already been loaded to a binary string:
    #   require 'dicom'
    #   dcm = DICOM::DObject.parse(str)
    #   # Parse a header-less DICOM string with explicit little endian transfer syntax:
    #   dcm = DICOM::DObject.parse(str, :syntax => '1.2.840.10008.1.2.1')
    #
    def self.parse(string, options={})
      raise ArgumentError, "Invalid argument 'string'. Expected String, got #{string.class}." unless string.is_a?(String)
      raise ArgumentError, "Invalid option :syntax. Expected String, got #{options[:syntax].class}." if options[:syntax] && !options[:syntax].is_a?(String)
      dcm = self.new
      dcm.send(:read, string, :no_meta => options[:no_meta], :syntax => options[:syntax])
      if dcm.read?
        logger.debug("DICOM string successfully parsed.")
      else
        logger.warn("Failed to parse this string as DICOM.")
      end
      return dcm
    end

    # Creates a DObject instance by reading and parsing a DICOM file.
    #
    # === Parameters
    #
    # * <tt>file</tt> -- A string which specifies the path of the DICOM file to be loaded.
    #
    # === Examples
    #
    #   # Load a DICOM file:
    #   require 'dicom'
    #   dcm = DICOM::DObject.read('test.dcm')
    #
    def self.read(file)
      raise ArgumentError, "Invalid argument 'file'. Expected String, got #{file.class}." unless file.is_a?(String)
      # Read the file content:
      bin = nil
      unless File.exist?(file)
        logger.error("Invalid (non-existing) file: #{file}")
      else
        unless File.readable?(file)
          logger.error("File exists but I don't have permission to read it: #{file}")
        else
          if File.directory?(file)
            logger.error("Expected a file, got a directory: #{file}")
          else
            if File.size(file) < 8
              logger.error("This file is too small to contain any DICOM information: #{file}.")
            else
              bin = File.open(file, "rb") { |f| f.read }
            end
          end
        end
      end
      # Parse the file contents and create the DICOM object:
      if bin
        dcm = self.parse(bin)
        # If reading failed, and no transfer syntax was detected, we will make another attempt at reading the file while forcing explicit (little endian) decoding.
        # This will help for some rare cases where the DICOM file is saved (erroneously, Im sure) with explicit encoding without specifying the transfer syntax tag.
        if !dcm.read? and !dcm.exists?("0002,0010")
          logger.info("Attempting a second decode pass (assuming Explicit Little Endian transfer syntax).")
          dcm = self.parse(bin, :syntax => EXPLICIT_LITTLE_ENDIAN)
        end
      else
        dcm = self.new
      end
      if dcm.read?
        logger.info("DICOM file successfully read: #{file}")
      else
        logger.warn("Reading DICOM file failed: #{file}")
      end
      return dcm
    end

    # Creates a DObject instance (DObject is an abbreviation for "DICOM object").
    #
    # === Notes
    #
    # The DObject instance holds references to the different types of objects (Element, Item, Sequence)
    # that makes up a DICOM object. A DObject is typically buildt by reading and parsing a file or a
    # binary string, but can also be buildt from an empty state by the user.
    #
    # To customize logging behaviour, refer to the Logging module documentation.
    #
    # === Examples
    #
    #   # Create an empty DICOM object:
    #   require 'dicom'
    #   dcm = DICOM::DObject.new
    #   # Increasing the log message threshold (default level is INFO):
    #   DICOM.logger.level = Logger::ERROR
    #
    def initialize
      # Initialization of variables that DObject share with other parent elements:
      initialize_parent
      # Structural information (default values):
      @explicit = true
      @str_endian = false
      # Control variables:
      @read_success = nil
      # Initialize a Stream instance which is used for encoding/decoding:
      @stream = Stream.new(nil, @str_endian)
      # The DObject instance is the top of the hierarchy and unlike other elements it has no parent:
      @parent = nil
    end

    # Returns true if the argument is an instance with attributes equal to self.
    #
    def ==(other)
      if other.respond_to?(:to_dcm)
        other.send(:state) == state
      end
    end

    alias_method :eql?, :==

    # Encodes the DICOM object into a series of binary string segments with a specified maximum length.
    #
    # Returns the encoded binary strings in an array.
    #
    # === Parameters
    #
    # * <tt>max_size</tt> -- An integer (Fixnum) which specifies the maximum allowed size of the binary data strings which will be encoded.
    # * <tt>transfer_syntax</tt> -- The transfer syntax string to be used when encoding the DICOM object to string segments. When this method is used for making network packets, the transfer_syntax is not part of the object, and thus needs to be specified. Defaults to the DObject's transfer syntax/Implicit little endian.
    #
    # === Examples
    #
    #  encoded_strings = dcm.encode_segments(16384)
    #
    def encode_segments(max_size, transfer_syntax=IMPLICIT_LITTLE_ENDIAN)
      raise ArgumentError, "Invalid argument. Expected an Integer, got #{max_size.class}." unless max_size.is_a?(Integer)
      raise ArgumentError, "Argument too low (#{max_size}), please specify a bigger Integer." unless max_size > 16
      raise "Can not encode binary segments for an empty DICOM object." if children.length == 0
      encode_in_segments(max_size, :syntax => transfer_syntax)
    end

    # Generates a Fixnum hash value for this instance.
    #
    def hash
      state.hash
    end

    # Prints information of interest related to the DICOM object.
    # Calls the print() method of Parent as well as the information() method of DObject.
    #
    def print_all
      puts ""
      print(:value_max => 30)
      summary
    end

    # Gathers key information about the DObject as well as some system data, and prints this information to the screen.
    #
    # This information includes properties like encoding, byte order, modality and various image properties.
    #
    #--
    # FIXME: Perhaps this method should be split up in one or two separate methods
    # which just builds the information arrays, and a third method for printing this to the screen.
    #
    def summary
      sys_info = Array.new
      info = Array.new
      # Version of Ruby DICOM used:
      sys_info << "Ruby DICOM version:   #{VERSION}"
      # System endian:
      cpu = (CPU_ENDIAN ? "Big Endian" : "Little Endian")
      sys_info << "Byte Order (CPU):     #{cpu}"
      # File path/name:
      info << "File:                 #{@file}"
      # Modality:
      modality = (exists?("0008,0016") ? LIBRARY.get_syntax_description(self["0008,0016"].value) : "SOP Class unknown or not specified!")
      info << "Modality:             #{modality}"
      # Meta header presence (Simply check for the presence of the transfer syntax data element), VR and byte order:
      transfer_syntax = self["0002,0010"]
      if transfer_syntax
        syntax_validity, explicit, endian = LIBRARY.process_transfer_syntax(transfer_syntax.value)
        if syntax_validity
          meta_comment, explicit_comment, encoding_comment = "", "", ""
        else
          meta_comment = " (But unknown/invalid transfer syntax: #{transfer_syntax})"
          explicit_comment = " (Assumed)"
          encoding_comment = " (Assumed)"
        end
        explicitness = (explicit ? "Explicit" : "Implicit")
        encoding = (endian ? "Big Endian" : "Little Endian")
        meta = "Yes#{meta_comment}"
      else
        meta = "No"
        explicitness = (@explicit == true ? "Explicit" : "Implicit")
        encoding = (@str_endian == true ? "Big Endian" : "Little Endian")
        explicit_comment = " (Assumed)"
        encoding_comment = " (Assumed)"
      end
      info << "Meta Header:          #{meta}"
      info << "Value Representation: #{explicitness}#{explicit_comment}"
      info << "Byte Order (File):    #{encoding}#{encoding_comment}"
      # Pixel data:
      pixels = self[PIXEL_TAG]
      unless pixels
        info << "Pixel Data:           No"
      else
        info << "Pixel Data:           Yes"
        # Image size:
        cols = (exists?("0028,0011") ? self["0028,0011"].value : "Columns missing")
        rows = (exists?("0028,0010") ? self["0028,0010"].value : "Rows missing")
        info << "Image Size:           #{cols}*#{rows}"
        # Frames:
        frames = value("0028,0008") || "1"
        unless frames == "1" or frames == 1
          # Encapsulated or 3D pixel data:
          if pixels.is_a?(Element)
            frames = frames.to_s + " (3D Pixel Data)"
          else
            frames = frames.to_s + " (Encapsulated Multiframe Image)"
          end
        end
        info << "Number of frames:     #{frames}"
        # Color:
        colors = (exists?("0028,0004") ? self["0028,0004"].value : "Not specified")
        info << "Photometry:           #{colors}"
        # Compression:
        if transfer_syntax
          compression = LIBRARY.get_compression(transfer_syntax.value)
          if compression
            compression = LIBRARY.get_syntax_description(transfer_syntax.value) || "Unknown UID!"
          else
            compression = "No"
          end
        else
          compression = "No (Assumed)"
        end
        info << "Compression:          #{compression}"
        # Pixel bits (allocated):
        bits = (exists?("0028,0100") ? self["0028,0100"].value : "Not specified")
        info << "Bits per Pixel:       #{bits}"
      end
      # Print the DICOM object's key properties:
      separator = "-------------------------------------------"
      puts "System Properties:"
      puts separator + "\n"
      puts sys_info
      puts "\n"
      puts "DICOM Object Properties:"
      puts separator
      puts info
      puts separator
      return info
    end

    # Returns self.
    #
    def to_dcm
      self
    end

    # Returns the transfer syntax string of the DObject.
    #
    # If a transfer syntax has not been defined in the DObject, a default tansfer syntax is assumed and returned.
    #
    def transfer_syntax
      return value("0002,0010") || IMPLICIT_LITTLE_ENDIAN
    end

    # Changes the transfer syntax Element of the DObject instance, and performs re-encoding of all
    # numerical values if a switch of endianness is implied.
    #
    # === Restrictions
    #
    # This method does not change the compressed state of the pixel data element. Changing the transfer syntax between
    # an uncompressed and compressed state will NOT change the pixel data accordingly (this must be taken care of manually).
    #
    # === Parameters
    #
    # * <tt>new_syntax</tt> -- The new transfer syntax string which will be applied to the DObject.
    #
    def transfer_syntax=(new_syntax)
      valid_ts, new_explicit, new_endian = LIBRARY.process_transfer_syntax(new_syntax)
      raise ArgumentError, "Invalid transfer syntax specified: #{new_syntax}" unless valid_ts
      # Get the old transfer syntax and write the new one to the DICOM object:
      old_syntax = transfer_syntax
      valid_ts, old_explicit, old_endian = LIBRARY.process_transfer_syntax(old_syntax)
      if exists?("0002,0010")
        self["0002,0010"].value = new_syntax
      else
        add(Element.new("0002,0010", new_syntax))
      end
      # Update our Stream instance with the new encoding:
      @stream.endian = new_endian
      # If endianness is changed, re-encode elements (only elements depending on endianness will actually be re-encoded):
      encode_children(old_endian) if old_endian != new_endian
    end

    # Writes the DICOM object to file.
    #
    # === Notes
    #
    # The goal of the Ruby DICOM library is to yield maximum conformance with
    # the DICOM standard when outputting DICOM files. Therefore, when encoding
    # the DICOM file, manipulation of items such as the meta group, group lengths
    # and header signature may occur.
    #
    # Therefore, the file that is written may not be an exact bitwise copy of the
    # file that was read, even if no DObject manipulation has been done by the user.
    #
    # === Parameters
    #
    # * <tt>file_name</tt> -- String. The path & name of the DICOM file which is to be written to disk.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:add_meta</tt> -- (Deprecated) If set to false, no manipulation of the DICOM object's meta group will be performed before the DObject is written to file.
    # * <tt>:ignore_meta</tt> -- Boolean. If true, no manipulation of the DICOM object's meta group will be performed before the DObject is written to file.
    #
    # === Examples
    #
    #   dcm.write('C:/dicom/test.dcm')
    #
    def write(file_name, options={})
      logger.warn("Option :add_meta => false is deprecated. Use option :ignore_meta => true instead.") if options[:add_meta] == false
      raise ArgumentError, "Invalid file_name. Expected String, got #{file_name.class}." unless file_name.is_a?(String)
      insert_missing_meta unless options[:add_meta] == false or options[:ignore_meta]
      write_elements(:file_name => file_name, :signature => true, :syntax => transfer_syntax)
    end


    private


    # Adds any missing meta group (0002,xxxx) data elements to the DICOM object,
    # to ensure that a valid DICOM object will be written to file.
    #
    def insert_missing_meta
      # File Meta Information Version:
      Element.new("0002,0001", [0,1], :parent => self) unless exists?("0002,0001")
      # Media Storage SOP Class UID:
      Element.new("0002,0002", value("0008,0016"), :parent => self) unless exists?("0002,0002")
      # Media Storage SOP Instance UID:
      Element.new("0002,0003", value("0008,0018"), :parent => self) unless exists?("0002,0003")
      # Transfer Syntax UID:
      Element.new("0002,0010", transfer_syntax, :parent => self) unless exists?("0002,0010")
      if !exists?("0002,0012") and !exists?("0002,0013")
        # Implementation Class UID:
        Element.new("0002,0012", UID, :parent => self)
        # Implementation Version Name:
        Element.new("0002,0013", NAME, :parent => self)
      end
      # Source Application Entity Title:
      Element.new("0002,0016", DICOM.source_app_title, :parent => self) unless exists?("0002,0016")
      # Group Length: Delete the old one (if it exists) before creating a new one.
      delete("0002,0000")
      Element.new("0002,0000", meta_group_length, :parent => self)
    end

    # Determines and returns the length of the meta group in the DObject instance.
    #
    def meta_group_length
      group_length = 0
      meta_elements = group(META_GROUP)
      tag = 4
      vr = 2
      meta_elements.each do |element|
        case element.vr
          when "OB","OW","OF","SQ","UN","UT"
            length = 6
          else
            length = 2
        end
        group_length += tag + vr + length + element.bin.length
      end
      return group_length
    end

    # Returns the attributes (children) of this instance (for comparison purposes).
    #
    def state
      @tags
    end

  end
end
