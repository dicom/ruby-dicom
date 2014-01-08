#    Copyright 2008-2014 Christoffer Lervag
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

    # An attribute set as nil. This attribute is included to provide consistency with the other element types which usually have a parent defined.
    attr_reader :parent
    # A boolean which is set as true if a DICOM file has been successfully read & parsed from a file (or binary string).
    attr_accessor :read_success
    # The source of the DObject (nil, :str or file name string).
    attr_accessor :source
    # The Stream instance associated with this DObject instance (this attribute is mostly used internally).
    attr_reader :stream
    # An attribute (used by e.g. DICOM.load) to indicate that a DObject-type instance was given to the load method (instead of e.g. a file).
    attr_accessor :was_dcm_on_input
    # A boolean which is set as true if a DObject instance has been successfully written to file (or successfully encoded).
    attr_reader :write_success

    alias_method :read?, :read_success
    alias_method :written?, :write_success

    # Creates a DObject instance by downloading a DICOM file
    # specified by a hyperlink, and parsing the retrieved file.
    #
    # @note Highly experimental and un-tested!
    # @note Designed for the HTTP protocol only.
    # @note Whether this method should be included or removed from ruby-dicom is up for debate.
    #
    # @param [String] link a hyperlink string which specifies remote location of the DICOM file to be loaded
    # @return [DObject] the created DObject instance
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
      dcm.source = link
      return dcm
    end

    # Creates a DObject instance by parsing an encoded binary DICOM string.
    #
    # @param [String] string an encoded binary string containing DICOM information
    # @param [Hash] options the options to use for parsing the DICOM string
    # @option options [Boolean] :overwrite for the rare case of a DICOM file containing duplicate elements, setting this as true instructs the parsing algorithm to overwrite the original element with duplicates
    # @option options [Boolean] :signature if set as false, the parsing algorithm will not be looking for the DICOM header signature (defaults to true)
    # @option options [String] :syntax if a syntax string is specified, the parsing algorithm will be forced to use this transfer syntax when decoding the binary string
    # @example Parse a DICOM file that has already been loaded to a binary string
    #   require 'dicom'
    #   dcm = DICOM::DObject.parse(str)
    # @example Parse a header-less DICOM string with explicit little endian transfer syntax
    #   dcm = DICOM::DObject.parse(str, :syntax => '1.2.840.10008.1.2.1')
    #
    def self.parse(string, options={})
      raise ArgumentError, "Invalid argument 'string'. Expected String, got #{string.class}." unless string.is_a?(String)
      raise ArgumentError, "Invalid option :syntax. Expected String, got #{options[:syntax].class}." if options[:syntax] && !options[:syntax].is_a?(String)
      signature = options[:signature].nil? ? true : options[:signature]
      dcm = self.new
      dcm.send(:read, string, signature, :overwrite => options[:overwrite], :syntax => options[:syntax])
      if dcm.read?
        logger.debug("DICOM string successfully parsed.")
      else
        logger.warn("Failed to parse this string as DICOM.")
      end
      dcm.source = :str
      return dcm
    end

    # Creates a DObject instance by reading and parsing a DICOM file.
    #
    # @param [String] file a string which specifies the path of the DICOM file to be loaded
    # @param [Hash] options the options to use for reading the DICOM file
    # @option options [Boolean] :overwrite for the rare case of a DICOM file containing duplicate elements, setting this as true instructs the parsing algorithm to overwrite the original element with duplicates
    # @example Load a DICOM file
    #   require 'dicom'
    #   dcm = DICOM::DObject.read('test.dcm')
    #
    def self.read(file, options={})
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
        dcm = self.parse(bin, options)
        # If reading failed, and no transfer syntax was detected, we will make another attempt at reading the file while forcing explicit (little endian) decoding.
        # This will help for some rare cases where the DICOM file is saved (erroneously, Im sure) with explicit encoding without specifying the transfer syntax tag.
        if !dcm.read? and !dcm.exists?("0002,0010")
          logger.info("Attempting a second decode pass (assuming Explicit Little Endian transfer syntax).")
          options[:syntax] = EXPLICIT_LITTLE_ENDIAN
          dcm = self.parse(bin, options)
        end
      else
        dcm = self.new
      end
      if dcm.read?
        logger.info("DICOM file successfully read: #{file}")
      else
        logger.warn("Reading DICOM file failed: #{file}")
      end
      dcm.source = file
      return dcm
    end

    # Creates a DObject instance (DObject is an abbreviation for "DICOM object").
    #
    # The DObject instance holds references to the different types of objects (Element, Item, Sequence)
    # that makes up a DICOM object. A DObject is typically buildt by reading and parsing a file or a binary
    # string (with DObject::read or ::parse), but can also be buildt from an empty state by this method.
    #
    # To customize logging behaviour, refer to the Logging module documentation.
    #
    # @example Create an empty DICOM object
    #   require 'dicom'
    #   dcm = DICOM::DObject.new
    # @example Increasing the log message threshold (default level is INFO)
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

    # Checks for equality.
    #
    # Other and self are considered equivalent if they are
    # of compatible types and their attributes are equivalent.
    #
    # @param other an object to be compared with self.
    # @return [Boolean] true if self and other are considered equivalent
    #
    def ==(other)
      if other.respond_to?(:to_dcm)
        other.send(:state) == state
      end
    end

    alias_method :eql?, :==

    # Performs de-identification (anonymization) on the DICOM object.
    #
    # @param [Anonymizer] a an Anonymizer instance to use for the anonymization
    #
    def anonymize(a=Anonymizer.new)
      a.to_anonymizer.anonymize(self)
    end

    # Encodes the DICOM object into a series of binary string segments with a specified maximum length.
    #
    # Returns the encoded binary strings in an array.
    #
    # @param [Integer] max_size the maximum allowed size of the binary data strings to be encoded
    # @param [String] transfer_syntax the transfer syntax string to be used when encoding the DICOM object to string segments. When this method is used for making network packets, the transfer_syntax is not part of the object, and thus needs to be specified.
    # @return [Array<String>] the encoded DICOM strings
    # @example Encode the DObject to strings of max length 2^14 bytes
    #   encoded_strings = dcm.encode_segments(16384)
    #
    def encode_segments(max_size, transfer_syntax=IMPLICIT_LITTLE_ENDIAN)
      raise ArgumentError, "Invalid argument. Expected an Integer, got #{max_size.class}." unless max_size.is_a?(Integer)
      raise ArgumentError, "Argument too low (#{max_size}), please specify a bigger Integer." unless max_size > 16
      raise "Can not encode binary segments for an empty DICOM object." if children.length == 0
      encode_in_segments(max_size, :syntax => transfer_syntax)
    end

    # Computes a hash code for this object.
    #
    # @note Two objects with the same attributes will have the same hash code.
    #
    # @return [Fixnum] the object's hash code
    #
    def hash
      state.hash
    end

    # Prints information of interest related to the DICOM object.
    # Calls the Parent#print method as well as DObject#summary.
    #
    def print_all
      puts ""
      print(:value_max => 30)
      summary
    end

    # Gathers key information about the DObject as well as some system data, and prints this information to the screen.
    # This information includes properties like encoding, byte order, modality and various image properties.
    #
    # @return [Array<String>] strings describing the properties of the DICOM object
    #
    def summary
      # FIXME: Perhaps this method should be split up in one or two separate methods
      # which just builds the information arrays, and a third method for printing this to the screen.
      sys_info = Array.new
      info = Array.new
      # Version of Ruby DICOM used:
      sys_info << "Ruby DICOM version:   #{VERSION}"
      # System endian:
      cpu = (CPU_ENDIAN ? "Big Endian" : "Little Endian")
      sys_info << "Byte Order (CPU):     #{cpu}"
      # Source (file name):
      if @source
        if @source == :str
          source = "Binary string #{@read_success ? '(successfully parsed)' : '(failed to parse)'}"
        else
          source = "File #{@read_success ? '(successfully read)' : '(failed to read)'}: #{@source}"
        end
      else
        source = 'Created from scratch'
      end
      info << "Source:               #{source}"
      # Modality:
      modality = (LIBRARY.uid(value('0008,0016')) ? LIBRARY.uid(value('0008,0016')).name : "SOP Class unknown or not specified!")
      info << "Modality:             #{modality}"
      # Meta header presence (Simply check for the presence of the transfer syntax data element), VR and byte order:
      ts_status = self['0002,0010'] ? '' : ' (Assumed)'
      ts = LIBRARY.uid(transfer_syntax)
      explicit = ts ? ts.explicit? : true
      endian = ts ? ts.big_endian? : false
      meta_comment = ts ? "" : " (But unknown/invalid transfer syntax: #{transfer_syntax})"
      info << "Meta Header:          #{self['0002,0010'] ? 'Yes' : 'No'}#{meta_comment}"
      info << "Value Representation: #{explicit ? 'Explicit' : 'Implicit'}#{ts_status}"
      info << "Byte Order (File):    #{endian ? 'Big Endian' : 'Little Endian'}#{ts_status}"
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
        compression = (ts ? (ts.compressed_pixels? ? ts.name : 'No') : 'No' )
        info << "Compression:          #{compression}#{ts_status}"
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
    # @return [DObject] self
    #
    def to_dcm
      self
    end

    # Gives the transfer syntax string of the DObject.
    #
    # If a transfer syntax has not been defined in the DObject, a default tansfer syntax is assumed and returned.
    #
    # @return [String] the DObject's transfer syntax
    #
    def transfer_syntax
      return value("0002,0010") || IMPLICIT_LITTLE_ENDIAN
    end

    # Changes the transfer syntax Element of the DObject instance, and performs re-encoding of all
    # numerical values if a switch of endianness is implied.
    #
    # @note This method does not change the compressed state of the pixel data element. Changing
    # the transfer syntax between an uncompressed and compressed state will NOT change the pixel
    # data accordingly (this must be taken care of manually).
    #
    # @param [String] new_syntax the new transfer syntax string to be applied to the DObject
    #
    def transfer_syntax=(new_syntax)
      # Verify old and new transfer syntax:
      new_uid = LIBRARY.uid(new_syntax)
      old_uid = LIBRARY.uid(transfer_syntax)
      raise ArgumentError, "Invalid/unknown transfer syntax specified: #{new_syntax}" unless new_uid && new_uid.transfer_syntax?
      raise ArgumentError, "Invalid/unknown existing transfer syntax: #{new_syntax} Unable to reliably handle byte order encoding. Modify the transfer syntax element directly instead." unless old_uid && old_uid.transfer_syntax?
      # Set the new transfer syntax:
      if exists?("0002,0010")
        self["0002,0010"].value = new_syntax
      else
        add(Element.new("0002,0010", new_syntax))
      end
      # Update our Stream instance with the new encoding:
      @stream.endian = new_uid.big_endian?
      # If endianness is changed, re-encode elements (only elements depending on endianness will actually be re-encoded):
      encode_children(old_uid.big_endian?) if old_uid.big_endian? != new_uid.big_endian?
    end

    # Writes the DICOM object to file.
    #
    # @note The goal of the Ruby DICOM library is to yield maximum conformance with the DICOM
    # standard when outputting DICOM files. Therefore, when encoding the DICOM file, manipulation
    # of items such as the meta group, group lengths and header signature may occur. Therefore,
    # the file that is written may not be an exact bitwise copy of the file that was read, even if no
    # DObject manipulation has been done by the user.
    #
    # @param [String] file_name the path of the DICOM file which is to be written to disk
    # @param [Hash] options the options to use for writing the DICOM file
    # @option options [Boolean] :ignore_meta if true, no manipulation of the DICOM object's meta group will be performed before the DObject is written to file
    # @option options [Boolean] :include_empty_parents if true, childless parents (sequences & items) are written to the DICOM file
    # @example Encode a DICOM file from a DObject
    #   dcm.write('C:/dicom/test.dcm')
    #
    def write(file_name, options={})
      raise ArgumentError, "Invalid file_name. Expected String, got #{file_name.class}." unless file_name.is_a?(String)
      @include_empty_parents = options[:include_empty_parents]
      insert_missing_meta unless options[:ignore_meta]
      write_elements(:file_name => file_name, :signature => true, :syntax => transfer_syntax)
    end


    private


    # Adds any missing meta group (0002,xxxx) data elements to the DICOM object,
    # to ensure that a valid DICOM object is encoded.
    #
    def insert_missing_meta
      {
        '0002,0001' => [0,1], # File Meta Information Version
        '0002,0002' => value('0008,0016'), # Media Storage SOP Class UID
        '0002,0003' => value('0008,0018'), # Media Storage SOP Instance UID
        '0002,0010' => transfer_syntax, # Transfer Syntax UID
        '0002,0016' => DICOM.source_app_title, # Source Application Entity Title
      }.each_pair do |tag, value|
        add_element(tag, value) unless exists?(tag)
      end
      if !exists?("0002,0012") && !exists?("0002,0013")
        # Implementation Class UID:
        add_element("0002,0012", UID_ROOT)
        # Implementation Version Name:
        add_element("0002,0013", NAME)
      end
      # Delete the old group length first (if it exists) to avoid a miscount
      # in the coming group length determination.
      delete("0002,0000")
      add_element("0002,0000", meta_group_length)
    end

    # Determines the length of the meta group in the DObject instance.
    #
    # @return [Integer] the length of the file meta group string
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
      group_length
    end

    # Collects the attributes of this instance.
    #
    # @return [Array<Element, Sequence>] an array of elements and sequences
    #
    def state
      @tags
    end

  end

end
