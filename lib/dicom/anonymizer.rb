
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

    # A boolean that if set as true will cause all anonymized tags to be blank instead of get some generic value.
    attr_accessor :blank
    # A boolean that if set as true will cause all anonymized tags to be get enumerated values, to enable post-anonymization identification by the user.
    attr_accessor :enumeration
    # A string, which if set (and enumeration has been set as well), will make the Anonymizer produce an identity file that provides a relationship between the original and enumerated, anonymized values.
    attr_accessor :identity_file
    # An array containing status messages accumulated for the Anonymization instance.
    attr_accessor :log
    # A boolean that if set as true, will make the anonymization remove all private tags.
    attr_accessor :remove_private
    # The path where the anonymized files will be saved. If this value is not set, the original DICOM files will be overwritten.
    attr_accessor :write_path

    # Creates an Anonymizer instance.
    #
    # === Parameters
    #
    # * <tt>options</tt> -- A hash of parameters.
    #
    # === Examples
    #
    #   a = Anonymizer.new
    #   # Create an instance in non-verbose mode:
    #   a = Anonymizer.new
    #   a.logger.level = Logger::UNKNOWN
    #
    #
    # To make changes in logging functionality please take a look at
    # Logging module.
    #
    def initialize(options={})
      # Default value of accessors:
      @blank = false
      @enumeration = false
      @identity_file = nil
      @remove_private = false
      @write_path = nil
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
      # Keep track of status messages:
      @log = Array.new
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
          @files.each_index do |i|
            # Read existing file to DICOM object:
            obj = DICOM::DObject.new(@files[i])
            if obj.read_success
              # Anonymize the desired tags:
              @tags.each_index do |j|
                if obj.exists?(@tags[j])
                  element = obj[@tags[j]]
                  if element.is_a?(Element)
                    if @blank
                      value = ""
                    elsif @enumeration
                      old_value = element.value
                      # Only launch enumeration logic if there is an actual value to the data element:
                      if old_value
                        value = get_enumeration_value(old_value, j)
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
              # Remove private tags?
              obj.remove_private if @remove_private
              # Write DICOM file:
              obj.write(@write_paths[i])
              if obj.write_success
                files_written += 1
              else
                all_write = false
              end
            else
              all_read = false
              files_failed_read += 1
            end
          end
          # Finished anonymizing files. Print elapsed time and status of anonymization:
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
          # Has user requested enumeration and specified an identity file in which to store the anonymized values?
          if @enumeration and @identity_file
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
        name, vr = LIBRARY.get_name_vr(@tags[i])
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
    #   a.set_tag("0010,0010, :value => "MrAnonymous", :enum => true)
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
        @values << (options[:value] ? options[:value] : "")
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

    # Handles the enumeration for the current data element tag.
    # If its value has been encountered before, its corresponding enumerated value is retrieved,
    # and if a new value is encountered, a new enumerated value is found by increasing an index by 1.
    # Returns the value which will be used for the anonymization of this tag.
    #
    # === Parameters
    #
    # * <tt>current</tt> -- The original value of the tag that are about to be anonymized.
    # * <tt>j</tt> -- Fixnum. The index of this tag in the tag-related instance arrays.
    #
    def get_enumeration_value(current, j)
      # Is enumeration requested for this tag?
      if @enumerations[j]
        # Retrieve earlier used anonymization values:
        previous_old = @enum_old_hash[@tags[j]]
        previous_new = @enum_new_hash[@tags[j]]
        p_index = previous_old.length
        if previous_old.index(current) == nil
          # Current value has not been encountered before:
          value = @values[j]+(p_index + 1).to_s
          # Store value in array (and hash):
          previous_old << current
          previous_new << value
          @enum_old_hash[@tags[j]] = previous_old
          @enum_new_hash[@tags[j]] = previous_new
        else
          # Current value has been observed before:
          value = previous_new[previous_old.index(current)]
        end
      else
        value = @values[j]
      end
      return value
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

    # Sets up the default tags that will be anonymized, along with default replacement values and enumeration settings.
    # The data is stored in 3 separate instance arrays for tags, values and enumeration.
    #
    def set_defaults
      data = [
      ["0008,0012", "20000101", false], # Instance Creation Date
      ["0008,0013", "000000.00", false], # Instance Creation Time
      ["0008,0020", "20000101", false], # Study Date
      ["0008,0023", "20000101", false], # Image Date
      ["0008,0030", "000000.00", false], # Study Time
      ["0008,0033", "000000.00", false], # Image Time
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
