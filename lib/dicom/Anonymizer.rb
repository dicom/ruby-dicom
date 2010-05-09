#    Copyright 2008-2010 Christoffer Lervag

module DICOM

  # This is a convenience class for handling the anonymization of DICOM files.
  # A good resource on this topic (report from the DICOM standards committee, work group 18):
  # ftp://medical.nema.org/medical/dicom/Supps/sup142_03.pdf
  class Anonymizer

    attr_accessor :blank, :enumeration, :identity_file, :remove_private, :verbose, :write_path

    # Initialize the Anonymizer instance.
    def initialize(opts={})
      # Default verbosity is true: # NB: verbosity is not used currently
      @verbose = opts[:verbose]
      @verbose = true if @verbose == nil
      # Default value of accessors:
      # Replace all values with a blank string?
      @blank = false
      # Enumerate selected replacement values?
      @enumeration = false
      # All private tags may be removed if desired:
      @remove_private = false
      # A separate path may be selected for writing the anonymized files:
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
      @enum = Array.new
      # We use a hash to store information from DICOM files if enumeration is desired:
      @enum_old_hash = {}
      @enum_new_hash = {}
      # All the files to be anonymized will be put in this array:
      @files = Array.new
      # Write paths will be determined later and put in this array:
      @write_paths = Array.new
      # Set the default data elements to be anonymized:
      set_defaults
    end


    # Adds an exception folder that is to be avoided when anonymizing.
    def add_exception(path)
      if path
        # Remove last character if the path ends with a file separator:
        path.chop! if path[-1..-1] == File::SEPARATOR
        @exceptions << path if path
      end
    end


    # Adds a folder who's files will be anonymized.
    def add_folder(path)
      @folders << path if path
    end


    # Adds a tag to the list of tags that will be anonymized.
    def add_tag(tag, opts={})
      # Options and defaults:
      value =  opts[:value]  || ""
      enum =  opts[:enum]  || false
      if tag
        if tag.is_a?(String)
          if tag.length == 9
            # Add anonymization information for this tag:
            @tags << tag
            @values << value
            @enum << enum
          else
            puts "Warning: Invalid tag length. Please use the form 'GGGG,EEEE'."
          end
        else
          puts "Warning: Tag is not a string. Can not add tag."
        end
      else
        puts "Warning: No tag supplied. Nothing to add."
      end
    end


    # Sets the enumeration status for a specific tag (toggle true/false).
    def change_enum(tag, enum)
      pos = @tags.index(tag)
      if pos
        if enum
          @enum[pos] = true
        else
          @enum[pos] = false
        end
      else
        puts "Specified tag not found in anonymization array. No changes made."
      end
    end


    # Changes the value used in anonymization for a specific tag.
    def change_value(tag, value)
      pos = @tags.index(tag)
      if pos
        if value
          @values[pos] = value
        else
          puts "No value were specified. No changes made."
        end
      else
        puts "Specified tag not found in anonymization array. No changes made."
      end
    end


    # Executes the anonymization process.
    # NB! Only anonymizes top level Data Elements for the time being!
    def execute(verbose=false)
      # Search through the folders to gather all the files to be anonymized:
      puts "*******************************************************"
      puts "Initiating anonymization process."
      start_time = Time.now.to_f
      puts "Searching for files..."
      load_files
      puts "Done."
      if @files.length > 0
        if @tags.length > 0
          puts @files.length.to_s + " files have been identified in the specified folder(s)."
          if @write_path
            # Determine the write paths, as anonymized files will be written to a separate location:
            puts "Processing write paths..."
            process_write_paths
            puts "Done"
          else
            # Overwriting old files:
            puts "Separate write folder not specified. Will overwrite existing DICOM files."
            @write_paths = @files
          end
          # If the user wants enumeration, we need to prepare variables for storing
          # existing information associated with each tag:
          create_enum_hash if @enumeration
          # Start the read/update/write process:
          puts "Initiating read/update/write process (This may take some time)..."
          # Monitor whether every file read/write was successful:
          all_read = true
          all_write = true
          files_written = 0
          files_failed_read = 0
          @files.each_index do |i|
            # Read existing file to DICOM object:
            obj = DICOM::DObject.new(@files[i], :verbose => verbose)
            if obj.read_success
              # Anonymize the desired tags:
              @tags.each_index do |j|
                if obj.exists?(@tags[j])
                  element = obj[@tags[j]]
                  if element.is_a?(DataElement)
                    if @blank
                      value = ""
                    elsif @enumeration
                      old_value = element.value
                      # Only launch enumeration logic if tag exists:
                      if old_value
                        value = get_enumeration_value(old_value, j)
                      else
                        value = ""
                      end
                    else
                      # Value is simply value in array:
                      value = @values[j]
                    end
                    element.value = value
                  elsif element.is_a?(Item)
                    # Possibly a binary data item:
                    element.bin = ""
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
          puts "Anonymization process completed!"
          if all_read
            puts "All files in specified folder(s) were SUCCESSFULLY read to DICOM objects."
          else
            puts "Some files were NOT successfully read (#{files_failed_read} files). If folder(s) contain non-DICOM files, this is probably the reason."
          end
          if all_write
            puts "All DICOM objects were SUCCESSFULLY written as DICOM files (#{files_written} files)."
          else
            puts "Some DICOM objects were NOT succesfully written to file. You are advised to have a closer look (#{files_written} files succesfully written)."
          end
          # Has user requested enumeration and specified an identity file in which to store the anonymized values?
          if @enumeration and @identity_file
            puts "Writing identity file."
            write_identity_file
            puts "Done"
          end
          elapsed = (end_time-start_time).to_s
          puts "Elapsed time: " + elapsed[0..elapsed.index(".")+1] + " seconds"
        else
          puts "No tags have been selected for anonymization. Aborting."
        end
      else
        puts "No files were found in specified folders. Aborting."
      end
      puts "*******************************************************"
    end # of execute


    # Prints a list of which tags are currently selected for anonymization along with
    # replacement values that will be used and enumeration status.
    def print
      # Extract the string lengths which are needed to make the formatting nice:
      names = Array.new
      types = Array.new
      tag_lengths = Array.new
      name_lengths = Array.new
      type_lengths = Array.new
      value_lengths = Array.new
      @tags.each_index do |i|
        arr = LIBRARY.get_name_vr(@tags[i])
        names << arr[0]
        types << arr[1]
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
          enum = @enum[i]
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
    def remove_tag(tag)
      pos = @tags.index(tag)
      if pos
        @tags.delete_at(pos)
        @values.delete_at(pos)
        @enum.delete_at(pos)
      else
        puts "Specified tag not found in anonymization array. No changes made."
      end
    end


    # The following methods are private:
    private


    # Finds the common path in an array of files, by performing a recursive search.
    # Returns the index of the last folder in str_arr that is common in all file paths.
    def common_path(str_arr, index)
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


    # Creates a hash that is used for storing information used when enumeration is desired.
    def create_enum_hash
      @enum.each_index do |i|
        @enum_old_hash[@tags[i]] = Array.new
        @enum_new_hash[@tags[i]] = Array.new
      end
    end


    # Handles enumeration for current DICOM tag.
    def get_enumeration_value(current, j)
      # Is enumeration requested for this tag?
      if @enum[j]
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


    # Discovers all the files contained in the specified directory and all its sub-directories.
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


    # Analyses the write_path and the 'read' file path to determine if the have some common root.
    # If there are parts of file that exist also in write path, it will not add those parts to write_path.
    def process_write_paths
      # First make sure @write_path ends with a file separator character:
      last_character = @write_path[-1..-1]
      @write_path = @write_path + File::SEPARATOR unless last_character == File::SEPARATOR
      # Differing behaviour if we have one, or several files in our array:
      if @files.length == 1
        # One file.
        # Write path is requested write path + old file name:
        str_arr = @files[0].split(File::SEPARATOR)
        @write_paths << @write_path + str_arr.last
      else
        # Several files.
        # Find out how much of the path they have in common, remove that and
        # add the remaining to the @write_path:
        str_arr = @files[0].split(File::SEPARATOR)
        last_match_index = common_path(str_arr, 0)
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


    # Default tags that will be anonymized, along with default replacement value and enumeration setting.
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
      @enum = data[2]
    end


    # Writes an identity file, which allows reidentification of DICOM files that have been anonymized
    # using the enumeration feature. Values will be saved in a text file, using semi colon delineation.
    def write_identity_file
      # Open file and prepare to write text:
      File.open( @identity_file, 'w' ) do |output|
        # Cycle through each
        @tags.each_index do |i|
          if @enum[i]
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


  end # of class
end # of module