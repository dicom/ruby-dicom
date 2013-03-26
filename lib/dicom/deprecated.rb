module DICOM

  class Anonymizer

    # Adds an exception folder which will be avoided when anonymizing.
    #
    # @deprecated Use Anonymizer#anonymize instead.
    # @param [String] path a path that will be avoided
    # @example Adding a folder
    #   a.add_exception("/home/dicom/tutorials/")
    #
    def add_exception(path)
      # Deprecation warning:
      logger.warn("The '#add_exception' method of the Anonymization class has been deprecated! Please use the '#anonymize' method with a dataset argument instead.")
      raise ArgumentError, "Expected String, got #{path.class}." unless path.is_a?(String)
      if path
        # Remove last character if the path ends with a file separator:
        path.chop! if path[-1..-1] == File::SEPARATOR
        @exceptions << path
      end
    end

    # Adds a folder who's files will be anonymized.
    #
    # @deprecated Use Anonymizer#anonymize instead.
    # @param [String] path a path that will be included in the anonymization
    # @example Adding a folder
    #   a.add_folder("/home/dicom")
    #
    def add_folder(path)
      # Deprecation warning:
      logger.warn("The '#add_exception' method of the Anonymization class has been deprecated! Please use the '#anonymize' method with a dataset argument instead.")
      raise ArgumentError, "Expected String, got #{path.class}." unless path.is_a?(String)
      @folders << path
    end

    # Executes the anonymization process.
    #
    # This method is run when all settings have been finalized for the Anonymization instance.
    #
    # @deprecated Use Anonymizer#anonymize instead.
    #
    def execute
      # Deprecation warning:
      logger.warn("The '#execute' method of the Anonymization class has been deprecated! Please use the '#anonymize' method instead.")
      # FIXME: This method has grown way too lengthy. It needs to be refactored one of these days.
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
              # Extract the data element parents to investigate for this DICOM object:
              parents = element_parents(dcm)
              parents.each do |parent|
                # Anonymize the desired tags:
                @tags.each_index do |j|
                  if parent.exists?(@tags[j])
                    element = parent[@tags[j]]
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
                # Delete elements marked for deletion:
                @delete.each_key do |tag|
                  parent.delete(tag) if parent.exists?(tag)
                end
              end
              # General DICOM object manipulation:
              # Add a Patient Identity Removed attribute (as per
              # DICOM PS 3.15, Annex E, E.1.1 De-Identifier, point 6):
              dcm.add(Element.new('0012,0062', 'YES'))
              # Delete (and replace) the File Meta Information (as per
              # DICOM PS 3.15, Annex E, E.1.1 De-Identifier, point 7):
              dcm.delete_group('0002')
              # Handle UIDs if requested:
              replace_uids(parents) if @uid
              # Delete private tags?
              dcm.delete_private if @delete_private
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
      logger.warn("Anonymizer#print is deprecated.")
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
        value_lengths[i] = '' if @blank
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
        s = ' '
        f1 = ' '*(tag_maxL-@tags[i].length+1)
        f2 = ' '*(name_maxL-names[i].length+1)
        f3 = ' '*(type_maxL-types[i].length+1)
        f4 = ' ' if @blank
        f4 = ' '*(value_maxL-@values[i].to_s.length+1) unless @blank
        if @enumeration
          enum = @enumerations[i]
        else
          enum = ''
        end
        if @blank
          value = ''
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


    private


    # Finds the common path (if any) in the instance file path array, by performing a recursive search
    # on the folders that make up the path of one such file.
    #
    # @param [Array<String>] str_arr an array of folder strings from the path of a select file
    # @param [Fixnum] index the index of the folder in str_arr to check against all file paths
    # @return [Fixnum] the index of the last folder in the path of the selected file that is common for all file paths
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
    # If there are parts of the file path that exists also in the write path, the common parts will
    # not be added to the write_path. The processed paths are put in a write_path instance array.
    #
    def process_write_paths
      @write_paths = Array.new
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

  end

end