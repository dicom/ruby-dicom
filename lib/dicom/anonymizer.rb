module DICOM

  # This is a convenience class for handling anonymization of DICOM files.
  #
  # === Notes
  #
  # For 'advanced' anonymization, a good resource might be:
  # ftp://medical.nema.org/medical/dicom/supps/sup142_pc.pdf
  # (Clinical Trials De-identification Profiles, DICOM Standards Committee, Working Group 18)
  #
  class Anonymizer
    include Logging

    # An AuditTrail instance used for this anonymization (if specified).
    attr_reader :audit_trail
    # The file name used for the AuditTrail serialization (if specified).
    attr_reader :audit_trail_file
    # A boolean that if set as true will cause all anonymized tags to be blank instead of get some generic value.
    attr_accessor :blank
    # A boolean that if set as true will cause all anonymized tags to be get enumerated values, to enable post-anonymization identification by the user.
    attr_accessor :enumeration
    # The identity file attribute.
    attr_reader :identity_file
    # A boolean that if set as true, will make the anonymization delete all private tags.
    attr_accessor :delete_private
    # The path where the anonymized files will be saved. If this value is not set, the original DICOM files will be overwritten.
    attr_accessor :write_path
    # A boolean indicating whether or not UIDs shall be replaced when executing the anonymization.
    attr_accessor :uid
    # The DICOM UID root to use when generating new UIDs.
    attr_accessor :uid_root
    # An array of UID tags that will be anonymized if the uid option is used.
    attr_accessor :uids

    # Creates an Anonymizer instance.
    #
    # === Notes
    #
    # * To customize logging behaviour, refer to the Logging module documentation.
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:audit_trail</tt> -- String. A file name path. If the file contains old audit data, these are loaded and used in the current anonymization.
    # * <tt>:uid</tt> -- Boolean. If true, all (top level) UIDs will be replaced with custom generated UIDs. To preserve UID relations in studies/series, the AuditTrail feature must be used.
    # * <tt>:uid_root</tt> -- String. An organization (or custom) UID root to use when replacing UIDs.
    #
    # === Examples
    #
    #   # Create an Anonymizer instance and restrict the log output:
    #   a = Anonymizer.new
    #   a.logger.level = Logger::ERROR
    #   # Carry out anonymization using the audit trail feature:
    #   a = Anonymizer.new(:audit_trail => "trail.json")
    #   a.enumeration = true
    #   a.folder = "//dicom/today/"
    #   a.write_path = "//anonymized/"
    #   a.execute
    #
    def initialize(options={})
      # Default value of accessors:
      @blank = false
      @enumeration = false
      @delete_private = false
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
      # Write paths will be determined later and put in this array:
      @write_paths = Array.new
      # Register the uid anonymization option:
      @uid = options[:uid]
      # Set the uid_root to be used when anonymizing study_uid series_uid and sop_instance_uid
      @uid_root = options[:uid_root] ? options[:uid_root] : UID
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
      end
      # Set the default data elements to be anonymized:
      set_defaults
    end

    # Adds an exception folder which will be avoided when anonymizing.
    #
    # === Parameters
    #
    # * <tt>path</tt> -- String. A path that will be avoided.
    #
    # === Examples
    #
    #   a.add_exception("/home/dicom/tutorials/")
    #
    def add_exception(path)
      raise ArgumentError, "Expected String, got #{path.class}." unless path.is_a?(String)
      if path
        # Remove last character if the path ends with a file separator:
        path.chop! if path[-1..-1] == File::SEPARATOR
        @exceptions << path
      end
    end

    # Adds a folder who's files will be anonymized.
    #
    # === Parameters
    #
    # * <tt>path</tt> -- String. A path that will be included in the anonymization.
    #
    # === Examples
    #
    #   a.add_folder("/home/dicom")
    #
    def add_folder(path)
      raise ArgumentError, "Expected String, got #{path.class}." unless path.is_a?(String)
      @folders << path
    end

    # Returns the enumeration status for this tag.
    # Returns nil if no match is found for the provided tag.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
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

    # Executes the anonymization process.
    #
    # This method is run when all settings have been finalized for the Anonymization instance.
    #
    # === Restrictions
    #
    # * Only top level data elements are anonymized!
    #
    #--
    # FIXME: This method has grown a bit lengthy. Perhaps it should be looked at one day.
    #
    def execute
      # Search through the folders to gather all the files to be anonymized:
      logger.info("Initiating anonymization process.")
      start_time = Time.now.to_f
      logger.info("Searching for files...")
      load_files
      logger.info("Done.")
      if @files.length > 0
        if @tags.length > 0
          logger.info(@files.length.to_s + " files have been identified in the specified folder(s).")
          if @write_path
            # Determine the write paths, as anonymized files will be written to a separate location:
            logger.info("Processing write paths...")
            process_write_paths
            logger.info("Done")
          else
            # Overwriting old files:
            logger.warn("Separate write folder not specified. Existing DICOM files will be overwritten.")
            @write_paths = @files
          end
          # If the user wants enumeration, we need to prepare variables for storing
          # existing information associated with each tag:
          create_enum_hash if @enumeration
          # Start the read/update/write process:
          logger.info("Initiating read/update/write process. This may take some time...")
          # Monitor whether every file read/write was successful:
          all_read = true
          all_write = true
          files_written = 0
          files_failed_read = 0
          begin
            require 'progressbar'
            pbar = ProgressBar.new("Anonymizing", @files.length)
          rescue LoadError
            pbar = nil
          end
          # Temporarily increase the log threshold to suppress messages from the DObject class:
          anonymizer_level = logger.level
          logger.level = Logger::FATAL
          @files.each_index do |i|
            pbar.inc if pbar
            # Read existing file to DICOM object:
            dcm = DObject.read(@files[i])
            if dcm.read?
              # Anonymize the desired tags:
              @tags.each_index do |j|
                if dcm.exists?(@tags[j])
                  element = dcm[@tags[j]]
                  if element.is_a?(Element)
                    if @blank
                      value = ""
                    elsif @enumeration
                      old_value = element.value
                      # Only launch enumeration logic if there is an actual value to the data element:
                      if old_value
                        value = enumerated_value(old_value, j)
                      else
                        value = ""
                      end
                    else
                      # Use the value that has been set for this tag:
                      value = @values[j]
                    end
                    element.value = value
                  end
                end
              end
              # Handle UIDs if requested:
              replace_uids(dcm) if @uid
              # Delete private tags?
              dcm.delete_private if @delete_private
              # Delete Tags marked for removal:
              @delete_tags.each_index do |j|
                dcm.delete(@delete_tags[j]) if dcm.exists?(@delete_tags[j])
              end
              # Write DICOM file:
              dcm.write(@write_paths[i])
              if dcm.written?
                files_written += 1
              else
                all_write = false
              end
            else
              all_read = false
              files_failed_read += 1
            end
          end
          pbar.finish if pbar
          # Finished anonymizing files. Reset the log threshold:
          logger.level = anonymizer_level
          # Print elapsed time and status of anonymization:
          end_time = Time.now.to_f
          logger.info("Anonymization process completed!")
          if all_read
            logger.info("All files in the specified folder(s) were SUCCESSFULLY read to DICOM objects.")
          else
            logger.warn("Some files were NOT successfully read (#{files_failed_read} files). If some folder(s) contain non-DICOM files, this is expected.")
          end
          if all_write
            logger.info("All DICOM objects were SUCCESSFULLY written as DICOM files (#{files_written} files).")
          else
            logger.warn("Some DICOM objects were NOT succesfully written to file. You are advised to investigate the result (#{files_written} files succesfully written).")
          end
          @audit_trail.write(@audit_trail_file) if @audit_trail
          # Has user requested enumeration and specified an identity file in which to store the anonymized values?
          if @enumeration and @identity_file and !@audit_trail
            logger.info("Writing identity file.")
            write_identity_file
            logger.info("Done")
          end
          elapsed = (end_time-start_time).to_s
          logger.info("Elapsed time: #{elapsed[0..elapsed.index(".")+1]} seconds")
        else
          logger.warn("No tags were selected for anonymization. Aborting.")
        end
      else
        logger.warn("No files were found in specified folders. Aborting.")
      end
    end

    # Setter method for the identity file.
    # NB! The identity file feature is deprecated!
    # Please use the AuditTrail feature instead.
    #
    def identity_file=(file_name)
      # Deprecation warning:
      logger.warn("The identity_file feature of the Anonymization class has been deprecated! Please use the AuditTrail feature instead.")
      @identity_file = file_name
    end

    # Prints to screen a list of which tags are currently selected for anonymization along with
    # the replacement values that will be used and enumeration status.
    #
    def print
      # Extract the string lengths which are needed to make the formatting nice:
      names = Array.new
      types = Array.new
      tag_lengths = Array.new
      name_lengths = Array.new
      type_lengths = Array.new
      value_lengths = Array.new
      @tags.each_index do |i|
        name, vr = LIBRARY.name_and_vr(@tags[i])
        names << name
        types << vr
        tag_lengths[i] = @tags[i].length
        name_lengths[i] = names[i].length
        type_lengths[i] = types[i].length
        value_lengths[i] = @values[i].to_s.length unless @blank
        value_lengths[i] = "" if @blank
      end
      # To give the printed output a nice format we need to check the string lengths of some of these arrays:
      tag_maxL = tag_lengths.max
      name_maxL = name_lengths.max
      type_maxL = type_lengths.max
      value_maxL = value_lengths.max
      # Format string array for print output:
      lines = Array.new
      @tags.each_index do |i|
        # Configure empty spaces:
        s = " "
        f1 = " "*(tag_maxL-@tags[i].length+1)
        f2 = " "*(name_maxL-names[i].length+1)
        f3 = " "*(type_maxL-types[i].length+1)
        f4 = " " if @blank
        f4 = " "*(value_maxL-@values[i].to_s.length+1) unless @blank
        if @enumeration
          enum = @enumerations[i]
        else
          enum = ""
        end
        if @blank
          value = ""
        else
          value = @values[i]
        end
        tag = @tags[i]
        lines << tag + f1 + names[i] + f2 + types[i] + f3 + value.to_s + f4 + enum.to_s
      end
      # Print to screen:
      lines.each do |line|
        puts line
      end
    end

    # Removes a tag from the list of tags that will be anonymized.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
    #
    # === Examples
    #
    #   a.remove_tag("0010,0010")
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

    # Compeletely deletes a tag from the file
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
    #
    # === Examples
    #
    #   a.delete_tag("0010,0010")
    #
    def delete_tag(tag)
      raise ArgumentError, "Expected String, got #{tag.class}." unless tag.is_a?(String)
      raise ArgumentError, "Expected a valid tag of format 'GGGG,EEEE', got #{tag}." unless tag.tag?
      @delete_tags.push(tag) if not @delete_tags.include?(tag)
    end

    # Sets the anonymization settings for the specified tag. If the tag is already present in the list
    # of tags to be anonymized, its settings are updated, and if not, a new tag entry is created.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Options
    #
    # * <tt>:value</tt> -- The replacement value to be used when anonymizing this data element. Defaults to the pre-existing value and "" for new tags.
    # * <tt>:enum</tt> -- Boolean. Specifies if enumeration is to be used for this tag. Defaults to the pre-existing value and false for new tags.
    #
    # === Examples
    #
    #   a.set_tag("0010,0010", :value => "MrAnonymous", :enum => true)
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

    # Returns the value which will be used when anonymizing this tag.
    # If enumeration is selected for the particular tag, a number will be
    # appended in addition to the string that is returned here.
    # Returns nil if no match is found for the provided tag.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- String. A data element tag.
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


    # The following methods are private:
    private


    # Finds the common path (if any) in the instance file path array, by performing a recursive search
    # on the folders that make up the path of one such file.
    # Returns the index of the last folder in the path of the selected file that is common for all file paths.
    #
    # === Parameters
    #
    # * <tt>str_arr</tt> -- An array of folder strings from the path of a select file.
    # * <tt>index</tt> -- Fixnum. The index of the folder in str_arr to check against all file paths.
    #
    def common_path(str_arr, index=0)
      common_folders = Array.new
      # Find out how much of the path is similar for all files in @files array:
      folder = str_arr[index]
      all_match = true
      @files.each do |f|
        all_match = false unless f.include?(folder)
      end
      if all_match
        # Need to check the next folder in the array:
        result = common_path(str_arr, index + 1)
      else
        # Current folder did not match, which means last possible match is current index -1.
        result = index - 1
      end
      return result
    end

    # Creates a hash that is used for storing information that is used when enumeration is selected.
    #
    def create_enum_hash
      @enumerations.each_index do |i|
        @enum_old_hash[@tags[i]] = Array.new
        @enum_new_hash[@tags[i]] = Array.new
      end
    end

    # Sets a default value to use for anonymizing the given tag.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- A tag string.
    #
    def default_value(tag)
      name, vr = LIBRARY.name_and_vr(tag)
      conversion = VALUE_CONVERSION[vr] || :to_s
      case conversion
      when :to_i then return 0
      when :to_f then return 0.0
      else
        # Assume type is string and return an empty string:
        return ""
      end
    end

    # Handles the enumeration for the given data element tag.
    # If its value has been encountered before, its corresponding enumerated
    # replacement value is retrieved, and if a new original value is encountered,
    # a new enumerated replacement value is found by increasing an index by 1.
    # Returns the replacement value which is used for the anonymization of the tag.
    #
    # === Parameters
    #
    # * <tt>original</tt> -- The original value of the tag that to be anonymized.
    # * <tt>j</tt> -- Fixnum. The index of this tag in the tag-related instance arrays.
    #
    def enumerated_value(original, j)
      # Is enumeration requested for this tag?
      if @enumerations[j]
        if @audit_trail
          # Check if the UID has been encountered already:
          replacement = @audit_trail.replacement(@tags[j], original)
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
            @audit_trail.add_record(@tags[j], original, replacement)
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

    # Discovers all the files contained in the specified directory (all its sub-directories),
    # and adds these files to the instance file array.
    #
    def load_files
      # Load find library:
      require 'find'
      # Iterate through the folders (and its subfolders) to extract all files:
      for dir in @folders
        Find.find(dir) do |path|
          if FileTest.directory?(path)
            proceed = true
            @exceptions.each do |e|
              proceed = false if e == path
            end
            if proceed
              next
            else
              Find.prune  # Don't look any further into this directory.
            end
          else
            @files << path  # Store the file in our array
          end
        end
      end
    end

    # Analyzes the write_path and the 'read' file path to determine if they have some common root.
    # If there are parts of the file path that exists also in the write path, the common parts will not be added to the write_path.
    # The processed paths are put in a write_path instance array.
    #
    def process_write_paths
      # First make sure @write_path ends with a file separator character:
      last_character = @write_path[-1..-1]
      @write_path = @write_path + File::SEPARATOR unless last_character == File::SEPARATOR
      # Differing behaviour if we have one, or several files in our array:
      if @files.length == 1
        # Write path is requested write path + old file name:
        str_arr = @files[0].split(File::SEPARATOR)
        @write_paths << @write_path + str_arr.last
      else
        # Several files.
        # Find out how much of the path they have in common, remove that and
        # add the remaining to the @write_path:
        str_arr = @files[0].split(File::SEPARATOR)
        last_match_index = common_path(str_arr)
        if last_match_index >= 0
          # Remove the matching folders from the path that will be added to @write_path:
          @files.each do |file|
            arr = file.split(File::SEPARATOR)
            part_to_write = arr[(last_match_index+1)..(arr.length-1)].join(File::SEPARATOR)
            @write_paths << @write_path + part_to_write
          end
        else
          # No common folders. Add all of original path to write path:
          @files.each do |file|
            @write_paths << @write_path + file
          end
        end
      end
    end

    # Replaces the UIDs of the given DICOM object.
    #
    # === Notes
    #
    # Empty UIDs are ignored (we don't generate new UIDs for these).
    # If AuditTrail is set, the relationship between old and new UIDs
    # are preserved, and the relations between files in a study/series
    # should remain valid.
    #
    #
    def replace_uids(dcm)
      @uids.each_pair do |tag, prefix|
        original = dcm.value(tag)
        if original && original.length > 0
          # We have a UID value, go ahead and replace it:
          if @audit_trail
            # Check if the UID has been encountered already:
            replacement = @audit_trail.replacement(tag, original)
            unless replacement
              # The UID has not been stored previously. Generate a new one:
              replacement = DICOM.generate_uid(@uid_root, prefix)
              # Add this tag record to the audit trail:
              @audit_trail.add_record(tag, original, replacement)
            end
            # Replace the UID in the DICOM object:
            dcm[tag].value = replacement
            # NB! The SOP Instance UID must also be written to the Media Storage SOP Instance UID tag:
            dcm["0002,0003"].value = replacement if tag == "0008,0018" && dcm.exists?("0002,0003")
          else
            # We don't care about preserving UID relations. Just insert a custom UID:
            dcm[tag].value = DICOM.generate_uid(@uid_root, prefix)
          end
        end
      end
    end

    # Sets up some default information variables that are used by the Anonymizer.
    #
    def set_defaults
      # A hash of UID tags to be replaced (if requested) and prefixes to use for each tag:
      @uids = {
        "0008,0018" => 3, # SOP Instance UID
        "0020,000D" => 1, # Study Instance UID
        "0020,000E" => 2, # Series Instance UID
        "0020,0052" => 9 # Frame of Reference UID
      }
      # Sets up default tags that will be anonymized, along with default replacement values and enumeration settings.
      # This data is stored in 3 separate instance arrays for tags, values and enumeration.
      data = [
      ["0008,0012", "20000101", false], # Instance Creation Date
      ["0008,0013", "000000.00", false], # Instance Creation Time
      ["0008,0020", "20000101", false], # Study Date
      ["0008,0023", "20000101", false], # Image Date
      ["0008,0030", "000000.00", false], # Study Time
      ["0008,0033", "000000.00", false], # Image Time
      ["0008,0050", "", true], # Accession Number
      ["0008,0080", "Institution", true], # Institution name
      ["0008,0090", "Physician", true], # Referring Physician's name
      ["0008,1010", "Station", true], # Station name
      ["0008,1070", "Operator", true], # Operator's Name
      ["0010,0010", "Patient", true], # Patient's name
      ["0010,0020", "ID", true], # Patient's ID
      ["0010,0030", "20000101", false], # Patient's Birth Date
      ["0010,0040", "N", false], # Patient's Sex
      ["0020,4000", "", false], # Image Comments
      ].transpose
      @tags = data[0]
      @values = data[1]
      @enumerations = data[2]

      # Tags to be deleted completely during anonymization
      @delete_tags = [
      ]
    end

    # Writes an identity file, which allows reidentification of DICOM files that have been anonymized
    # using the enumeration feature. Values are saved in a text file, using semi colon delineation.
    #
    def write_identity_file
      raise ArgumentError, "Expected String, got #{@identity_file.class}. Unable to write identity file." unless @identity_file.is_a?(String)
      # Open file and prepare to write text:
      File.open(@identity_file, 'w') do |output|
        # Cycle through each
        @tags.each_index do |i|
          if @enumerations[i]
            # This tag has had enumeration. Gather original and anonymized values:
            old_values = @enum_old_hash[@tags[i]]
            new_values = @enum_new_hash[@tags[i]]
            # Print the tag label, then new_value;old_value in the following rows.
            output.print @tags[i] + "\n"
            old_values.each_index do |j|
              output.print new_values[j].to_s.rstrip + ";" + old_values[j].to_s.rstrip + "\n"
            end
            # Print empty line for separation between different tags:
            output.print "\n"
          end
        end
      end
    end
  end
end
