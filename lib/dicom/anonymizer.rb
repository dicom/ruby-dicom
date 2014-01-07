module DICOM

  # This is a convenience class for handling the anonymization
  # (de-identification) of DICOM files.
  #
  # @note
  #   For a thorough introduction to the concept of DICOM anonymization,
  #   please refer to The DICOM Standard, Part 15: Security and System
  #   Management Profiles, Annex E: Attribute Confidentiality Profiles.
  #   For guidance on settings for individual data elements, please
  #   refer to DICOM PS 3.15, Annex E, Table E.1-1: Application Level
  #   Confidentiality Profile Attributes.
  #
  class Anonymizer
    include Logging

    # An AuditTrail instance used for this anonymization (if specified).
    attr_reader :audit_trail
    # The file name used for the AuditTrail serialization (if specified).
    attr_reader :audit_trail_file
    # A boolean that if set as true will cause all anonymized tags to be blank instead of get some generic value.
    attr_accessor :blank
    # An hash of elements (represented by tag keys) that will be deleted from the DICOM objects on anonymization.
    attr_reader :delete
    # A boolean that if set as true, will make the anonymization delete all private tags.
    attr_accessor :delete_private
    # The cryptographic hash function to be used for encrypting DICOM values recorded in an audit trail file.
    attr_reader :encryption
    # A boolean that if set as true will cause all anonymized tags to be get enumerated values, to enable post-anonymization re-identification by the user.
    attr_accessor :enumeration
    # The logger level which is applied to DObject operations during anonymization (defaults to Logger::FATAL).
    attr_reader :logger_level
    # A boolean that if set as true will cause all anonymized files to be written with random file names (if write_path has been specified).
    attr_accessor :random_file_name
    # A boolean that if set as true, will cause the anonymization to run on all levels of the DICOM file tag hierarchy.
    attr_accessor :recursive
    # A boolean indicating whether or not UIDs shall be replaced when executing the anonymization.
    attr_accessor :uid
    # The DICOM UID root to use when generating new UIDs.
    attr_accessor :uid_root
    # The path where the anonymized files will be saved. If this value is not set, the original DICOM files will be overwritten.
    attr_accessor :write_path

    # Creates an Anonymizer instance.
    #
    # @note To customize logging behaviour, refer to the Logging module documentation.
    # @param [Hash] options the options to create an anonymizer instance with
    # @option options [String] :audit_trail a file name path (if the file contains old audit data, these are loaded and used in the current anonymization)
    # @option options [Boolean] :blank toggles whether to set the values of anonymized elements as empty instead of some generic value
    # @option options [Boolean] :delete_private toggles whether private elements are to be deleted
    # @option options [TrueClass, Digest::Class] :encryption if set as true, the default hash function (MD5) will be used for representing DICOM values in an audit file. Otherwise a Digest class can be given, e.g. Digest::SHA256
    # @option options [Boolean] :enumeration toggles whether (some) elements get enumerated values (to enable post-anonymization re-identification)
    # @option options [Fixnum] :logger_level the logger level which is applied to DObject operations during anonymization (defaults to Logger::FATAL)
    # @option options [Boolean] :random_file_name toggles whether anonymized files will be given random file names when rewritten (in combination with the :write_path option)
    # @option options [Boolean] :recursive toggles whether to anonymize on all sub-levels of the DICOM object tag hierarchies
    # @option options [Boolean] :uid toggles whether UIDs will be replaced with custom generated UIDs (beware that to preserve UID relations in studies/series, the audit_trail feature must be used)
    # @option options [String] :uid_root an organization (or custom) UID root to use when replacing UIDs
    # @option options [String] :write_path a directory where the anonymized files are re-written (if not specified, files are overwritten)
    # @example Create an Anonymizer instance and increase the log output
    #   a = Anonymizer.new
    #   a.logger.level = Logger::INFO
    # @example Perform anonymization using the audit trail feature
    #   a = Anonymizer.new(:audit_trail => 'trail.json')
    #   a.enumeration = true
    #   a.write_path = '//anonymized/'
    #   a.anonymize('//dicom/today/')
    #
    def initialize(options={})
      # Transfer options to attributes:
      @blank = options[:blank]
      @delete_private = options[:delete_private]
      @enumeration = options[:enumeration]
      @logger_level = options[:logger_level] || Logger::FATAL
      @random_file_name = options[:random_file_name]
      @recursive = options[:recursive]
      @uid = options[:uid]
      @uid_root = options[:uid_root] ? options[:uid_root] : UID_ROOT
      @write_path = options[:write_path]
      # Array of folders to be processed for anonymization:
      @folders = Array.new
      # Folders that will be skipped:
      @exceptions = Array.new
      # Data elements which will be anonymized (the array will hold a list of tag strings):
      @tags = Array.new
      # Default values to use on anonymized data elements:
      @values = Array.new
      # Which data elements will have enumeration applied, if requested by the user:
      @enumerations = Array.new
      # We use a Hash to store information from DICOM files if enumeration is desired:
      @enum_old_hash = Hash.new
      @enum_new_hash = Hash.new
      # All the files to be anonymized will be put in this array:
      @files = Array.new
      @prefixes = Hash.new
      # Setup audit trail if requested:
      if options[:audit_trail]
        @audit_trail_file = options[:audit_trail]
        if File.exists?(@audit_trail_file) && File.size(@audit_trail_file) > 2
          # Load the pre-existing audit trail from file:
          @audit_trail = AuditTrail.read(@audit_trail_file)
        else
          # Start from scratch with an empty audit trail:
          @audit_trail = AuditTrail.new
        end
        # Set up encryption if indicated:
        if options[:encryption]
          require 'digest'
          if options[:encryption].respond_to?(:hexdigest)
            @encryption = options[:encryption]
          else
            @encryption = Digest::MD5
          end
        end
      end
      # Set the default data elements to be anonymized:
      set_defaults
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
      if other.respond_to?(:to_anonymizer)
        other.send(:state) == state
      end
    end

    alias_method :eql?, :==

    # Anonymizes the given DICOM data with the settings of this Anonymizer instance.
    #
    # @param [String, DObject, Array<String, DObject>] data single or multiple DICOM data (directories, file paths, binary strings, DICOM objects)
    # @return [Array<DObject>] an array of the anonymized DICOM objects
    #
    def anonymize(data)
      dicom = prepare(data)
      if @tags.length > 0
        dicom.each do |dcm|
          anonymize_dcm(dcm)
          # Write DICOM object to file unless it was passed to the anonymizer as an object:
          write(dcm) unless dcm.was_dcm_on_input
        end
      else
        logger.warn("No tags have been selected for anonymization. Aborting anonymization.")
      end
      # Reset the ruby-dicom log threshold to its original level:
      logger.level = @original_level
      # Save the audit trail (if used):
      @audit_trail.write(@audit_trail_file) if @audit_trail
      logger.info("Anonymization complete.")
      dicom
    end

    # Specifies that the given tag is to be completely deleted
    # from the anonymized DICOM objects.
    #
    # @param [String] tag a data element tag
    # @example Completely delete the Patient's Name tag from the DICOM files
    #   a.delete_tag('0010,0010')
    #
    def delete_tag(tag)
      raise ArgumentError, "Expected String, got #{tag.class}." unless tag.is_a?(String)
      raise ArgumentError, "Expected a valid tag of format 'GGGG,EEEE', got #{tag}." unless tag.tag?
      @delete[tag] = true
    end

    # Checks the enumeration status of this tag.
    #
    # @param [String] tag a data element tag
    # @return [Boolean, NilClass] the enumeration status of the tag, or nil if the tag has no match
    #
    def enum(tag)
      raise ArgumentError, "Expected String, got #{tag.class}." unless tag.is_a?(String)
      raise ArgumentError, "Expected a valid tag of format 'GGGG,EEEE', got #{tag}." unless tag.tag?
      pos = @tags.index(tag)
      if pos
        return @enumerations[pos]
      else
        logger.warn("The specified tag (#{tag}) was not found in the list of tags to be anonymized.")
        return nil
      end
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

    # Removes a tag from the list of tags that will be anonymized.
    #
    # @param [String] tag a data element tag
    # @example Do not anonymize the Patient's Name tag
    #   a.remove_tag('0010,0010')
    #
    def remove_tag(tag)
      raise ArgumentError, "Expected String, got #{tag.class}." unless tag.is_a?(String)
      raise ArgumentError, "Expected a valid tag of format 'GGGG,EEEE', got #{tag}." unless tag.tag?
      pos = @tags.index(tag)
      if pos
        @tags.delete_at(pos)
        @values.delete_at(pos)
        @enumerations.delete_at(pos)
      end
    end

    # Sets the anonymization settings for the specified tag. If the tag is already present in the list
    # of tags to be anonymized, its settings are updated, and if not, a new tag entry is created.
    #
    # @param [String] tag a data element tag
    # @param [Hash] options the anonymization settings for the specified tag
    # @option options [String, Integer, Float] :value the replacement value to be used when anonymizing this data element. Defaults to the pre-existing value and '' for new tags.
    # @option options [String, Integer, Float] :enum specifies if enumeration is to be used for this tag. Defaults to the pre-existing value and false for new tags.
    # @example Set the anonymization settings of the Patient's Name tag
    #   a.set_tag('0010,0010', :value => 'MrAnonymous', :enum => true)
    #
    def set_tag(tag, options={})
      raise ArgumentError, "Expected String, got #{tag.class}." unless tag.is_a?(String)
      raise ArgumentError, "Expected a valid tag of format 'GGGG,EEEE', got #{tag}." unless tag.tag?
      pos = @tags.index(tag)
      if pos
        # Update existing values:
        @values[pos] = options[:value] if options[:value]
        @enumerations[pos] = options[:enum] if options[:enum] != nil
      else
        # Add new elements:
        @tags << tag
        @values << (options[:value] ? options[:value] : default_value(tag))
        @enumerations << (options[:enum] ? options[:enum] : false)
      end
    end

    # Returns self.
    #
    # @return [Anonymizer] self
    #
    def to_anonymizer
      self
    end

    # Gives the value which will be used when anonymizing this tag.
    #
    # @note If enumeration is selected for a string type tag, a number will be
    #   appended in addition to the string that is returned here.
    #
    # @param [String] tag a data element tag
    # @return [String, Integer, Float, NilClass] the replacement value for the specified tag, or nil if the tag is not matched
    #
    def value(tag)
      raise ArgumentError, "Expected String, got #{tag.class}." unless tag.is_a?(String)
      raise ArgumentError, "Expected a valid tag of format 'GGGG,EEEE', got #{tag}." unless tag.tag?
      pos = @tags.index(tag)
      if pos
        return @values[pos]
      else
        logger.warn("The specified tag (#{tag}) was not found in the list of tags to be anonymized.")
        return nil
      end
    end


    private


    # Performs anonymization on a DICOM object.
    #
    # @param [DObject] dcm a DICOM object
    #
    def anonymize_dcm(dcm)
      # Extract the data element parents to investigate:
      parents = element_parents(dcm)
      parents.each do |parent|
        # Anonymize the desired tags:
        @tags.each_index do |j|
          if parent.exists?(@tags[j])
            element = parent[@tags[j]]
            if element.is_a?(Element)
              if @blank
                value = ''
              elsif @enumeration
                old_value = element.value
                # Only launch enumeration logic if there is an actual value to the data element:
                if old_value
                  value = enumerated_value(old_value, j)
                else
                  value = ''
                end
              else
                # Use the value that has been set for this tag:
                value = @values[j]
              end
              element.value = value
            end
          end
        end
        # Delete elements marked for deletion:
        @delete.each_key do |tag|
          parent.delete(tag) if parent.exists?(tag)
        end
      end
      # General DICOM object manipulation:
      # Add a Patient Identity Removed attribute (as per
      # DICOM PS 3.15, Annex E, E.1.1 De-Identifier, point 6):
      dcm.add(Element.new('0012,0062', 'YES'))
      # Add a De-Identification Method Code Sequence Item:
      dcm.add(Sequence.new('0012,0064')) unless dcm.exists?('0012,0064')
      i = dcm['0012,0064'].add_item
      i.add(Element.new('0012,0063', 'De-identified by the ruby-dicom Anonymizer'))
      # FIXME: At some point we should add a set of de-indentification method codes, as per
      #   DICOM PS 3.16 CID 7050 which corresponds to the settings chosen for the anonymizer.
      # Delete the old File Meta Information group (as per
      # DICOM PS 3.15, Annex E, E.1.1 De-Identifier, point 7):
      dcm.delete_group('0002')
      # Handle UIDs if requested:
      replace_uids(parents) if @uid
      # Delete private tags if indicated:
      dcm.delete_private if @delete_private
    end

    # Gives the value to be used for the audit trail, which is either
    # the original value itself, or an encrypted string based on it.
    #
    # @param [String, Integer, Float] original the original value of the tag to be anonymized
    # @return [String, Integer, Float] with encryption, a hash string is returned, otherwise the original value
    #
    def at_value(original)
      @encryption ? @encryption.hexdigest(original) : original
    end

    # Creates a hash that is used for storing information that is used when enumeration is selected.
    #
    def create_enum_hash
      @enumerations.each_index do |i|
        @enum_old_hash[@tags[i]] = Array.new
        @enum_new_hash[@tags[i]] = Array.new
      end
    end

    # Determines a default value to use for anonymizing the given tag.
    #
    # @param [String] tag a data element tag
    # @return [String, Integer, Float] the default replacement value for a given tag
    #
    def default_value(tag)
      name, vr = LIBRARY.name_and_vr(tag)
      conversion = VALUE_CONVERSION[vr]
      case conversion
      when :to_i then return 0
      when :to_f then return 0.0
      else
        # Assume type is string and return an empty string:
        return ''
      end
    end

    # Creates a write path for the given DICOM object, based on the object's
    # original file path and the write_path attribute.
    #
    # @param [DObject] dcm a DICOM object
    # @return [String] the destination directory path
    #
    def destination(dcm)
      # Separate the path from the source file string:
      file_start = dcm.source.rindex(File.basename(dcm.source))
      if file_start == 0
        source_dir = "."
      else
        source_dir = dcm.source[0..(file_start-1)]
      end
      source_folders = source_dir.split(File::SEPARATOR)
      target_folders = @write_path.split(File::SEPARATOR)
      # If the first element is the current dir symbol, get rid of it:
      source_folders.delete('.')
      # Check for equalness of folder names in a range limited by the shortest array:
      common_length = [source_folders.length, target_folders.length].min
      uncommon_index = nil
      common_length.times do |i|
        if target_folders[i] != source_folders[i]
          uncommon_index = i
          break
        end
      end
      # Create the output path by joining the two paths together using the determined index:
      append_path = uncommon_index ? source_folders[uncommon_index..-1] : nil
      [target_folders, append_path].compact.join(File::SEPARATOR)
    end

    # Extracts all parents from a DObject instance which potentially
    # have child (data) elements. This typically means the DObject
    # instance itself as well as items (i.e. not sequences).
    # Note that unless the @recursive attribute has been set,
    # this method will only return the DObject (placed inside an array).
    #
    # @param [DObject] dcm a DICOM object
    # @return [Array<DObject, Item>] an array containing either just a DObject or also all parental child items within the tag hierarchy
    #
    def element_parents(dcm)
      parents = Array.new
      parents << dcm
      if @recursive
        dcm.sequences.each do |s|
          parents += element_parents_recursive(s)
        end
      end
      parents
    end

    # Recursively extracts all item parents from a sequence instance (including
    # any sub-sequences) which actually contain child (data) elements.
    #
    # @param [Sequence] sequence a Sequence instance
    # @return [Array<Item>] an array containing items within the tag hierarchy that contains child elements
    #
    def element_parents_recursive(sequence)
      parents = Array.new
      sequence.items.each do |i|
        parents << i if i.elements?
        i.sequences.each do |s|
          parents += element_parents_recursive(s)
        end
      end
      parents
    end

    # Handles the enumeration for the given data element tag.
    # If its value has been encountered before, its corresponding enumerated
    # replacement value is retrieved, and if a new original value is encountered,
    # a new enumerated replacement value is found by increasing an index by 1.
    #
    # @param [String, Integer, Float] original the original value of the tag to be anonymized
    # @param [Fixnum] j the index of this tag in the tag-related instance arrays
    # @return [String, Integer, Float] the replacement value which is used for the anonymization of the tag
    #
    def enumerated_value(original, j)
      # Is enumeration requested for this tag?
      if @enumerations[j]
        if @audit_trail
          # Check if the UID has been encountered already:
          replacement = @audit_trail.replacement(@tags[j], at_value(original))
          unless replacement
            # This original value has not been encountered yet. Determine the index to use.
            index = @audit_trail.records(@tags[j]).length + 1
            # Create the replacement value:
            if @values[j].is_a?(String)
              replacement = @values[j] + index.to_s
            else
              replacement = @values[j] + index
            end
            # Add this tag record to the audit trail:
            @audit_trail.add_record(@tags[j], at_value(original), replacement)
          end
        else
          # Retrieve earlier used anonymization values:
          previous_old = @enum_old_hash[@tags[j]]
          previous_new = @enum_new_hash[@tags[j]]
          p_index = previous_old.length
          if previous_old.index(original) == nil
            # Current value has not been encountered before:
            replacement = @values[j]+(p_index + 1).to_s
            # Store value in array (and hash):
            previous_old << original
            previous_new << replacement
            @enum_old_hash[@tags[j]] = previous_old
            @enum_new_hash[@tags[j]] = previous_new
          else
            # Current value has been observed before:
            replacement = previous_new[previous_old.index(original)]
          end
        end
      else
        replacement = @values[j]
      end
      return replacement
    end

    # Establishes a prefix for a given UID tag.
    # This makes it somewhat easier to distinguish
    # between different types of random generated UIDs.
    #
    # @param [String] tag a data element string tag
    #
    def prefix(tag)
      if @prefixes[tag]
        @prefixes[tag]
      else
        @prefixes[tag] = @prefixes.length + 1
        @prefixes[tag]
      end
    end

    # Prepares the data for anonymization.
    #
    # @param [String, DObject, Array<String, DObject>] data single or multiple DICOM data (directories, file paths, binary strings, DICOM objects)
    # @return [Array] the original data (wrapped in an array) as well as an array of loaded DObject instances
    #
    def prepare(data)
      logger.info("Loading DICOM data.")
      # Temporarily adjust the ruby-dicom log threshold (usually to suppress messages from the DObject class):
      @original_level = logger.level
      logger.level = @logger_level
      dicom = DICOM.load(data)
      logger.level = @original_level
      logger.info("#{dicom.length} DICOM objects have been prepared for anonymization.")
      logger.level = @logger_level
      # Set up enumeration if requested:
      create_enum_hash if @enumeration
      require 'securerandom' if @random_file_name
      dicom
    end

    # Replaces the UIDs of the given DICOM object.
    #
    # @note Empty UIDs are ignored (we don't generate new UIDs for these).
    # @note If AuditTrail is set, the relationship between old and new UIDs are preserved,
    #   and the relations between files in a study/series should remain valid.
    # @param [Array<DObject, Item>] parents dicom parent objects who's child elements will be investigated
    #
    def replace_uids(parents)
      parents.each do |parent|
        parent.each_element do |element|
          if element.vr == ('UI') and !@static_uids[element.tag]
            original = element.value
            if original && original.length > 0
              # We have a UID value, go ahead and replace it:
              if @audit_trail
                # Check if the UID has been encountered already:
                replacement = @audit_trail.replacement('uids', original)
                unless replacement
                  # The UID has not been stored previously. Generate a new one:
                  replacement = DICOM.generate_uid(@uid_root, prefix(element.tag))
                  # Add this tag record to the audit trail:
                  @audit_trail.add_record('uids', original, replacement)
                end
                # Replace the UID in the DICOM object:
                element.value = replacement
              else
                # We don't care about preserving UID relations. Just insert a custom UID:
                element.value = DICOM.generate_uid(@uid_root, prefix(element.tag))
              end
            end
          end
        end
      end
    end

    # Sets up some default information variables that are used by the Anonymizer.
    #
    def set_defaults
      # Some UIDs should not be remapped even if uid anonymization has been requested:
      @static_uids = {
        # Private related:
        '0002,0100' => true,
        '0004,1432' => true,
        # Coding scheme related:
        '0008,010C' => true,
        '0008,010D' => true,
        # Transfer syntax related:
        '0002,0010' => true,
        '0400,0010' => true,
        '0400,0510' => true,
        '0004,1512' => true,
        # SOP class related:
        '0000,0002' => true,
        '0000,0003' => true,
        '0002,0002' => true,
        '0004,1510' => true,
        '0004,151A' => true,
        '0008,0016' => true,
        '0008,001A' => true,
        '0008,001B' => true,
        '0008,0062' => true,
        '0008,1150' => true,
        '0008,115A' => true
      }
      # Sets up default tags that will be anonymized, along with default replacement values and enumeration settings.
      # This data is stored in 3 separate instance arrays for tags, values and enumeration.
      data = [
        ['0008,0012', '20000101', false], # Instance Creation Date
        ['0008,0013', '000000.00', false], # Instance Creation Time
        ['0008,0020', '20000101', false], # Study Date
        ['0008,0021', '20000101', false], # Series Date
        ['0008,0022', '20000101', false], # Acquisition Date
        ['0008,0023', '20000101', false], # Image Date
        ['0008,0030', '000000.00', false], # Study Time
        ['0008,0031', '000000.00', false], # Series Time
        ['0008,0032', '000000.00', false], # Acquisition Time
        ['0008,0033', '000000.00', false], # Image Time
        ['0008,0050', '', true], # Accession Number
        ['0008,0080', 'Institution', true], # Institution name
        ['0008,0081', 'Address', true], # Institution Address
        ['0008,0090', 'Physician', true], # Referring Physician's name
        ['0008,1010', 'Station', true], # Station name
        ['0008,1040', 'Department', true], # Institutional Department name
        ['0008,1070', 'Operator', true], # Operator's Name
        ['0010,0010', 'Patient', true], # Patient's name
        ['0010,0020', 'ID', true], # Patient's ID
        ['0010,0030', '20000101', false], # Patient's Birth Date
        ['0010,0040', 'O', false], # Patient's Sex
        ['0010,1010', '', false], # Patient's Age
        ['0020,4000', '', false], # Image Comments
      ].transpose
      @tags = data[0]
      @values = data[1]
      @enumerations = data[2]
      # Tags to be deleted completely during anonymization:
      @delete = Hash.new
    end

    # Collects the attributes of this instance.
    #
    # @return [Array] an array of attributes
    #
    def state
       [
        @tags, @values, @enumerations, @delete, @blank,
        @delete_private, @enumeration, @logger_level,
        @random_file_name, @recursive, @uid, @uid_root, @write_path
       ]
    end

    # Writes a DICOM object to file.
    #
    # @param [DObject] dcm a DICOM object
    #
    def write(dcm)
      if @write_path
        # The DICOM object is to be written to a separate directory. If the
        # original and the new directories have a common root, this is taken into
        # consideration when determining the object's write path:
        path = destination(dcm)
        if @random_file_name
          file_name = "#{SecureRandom.hex(16)}.dcm"
        else
          file_name = File.basename(dcm.source)
        end
        dcm.write(File.join(path, file_name))
      else
        # The original DICOM file is overwritten with the anonymized DICOM object:
        dcm.write(dcm.source)
      end
    end

  end

end
