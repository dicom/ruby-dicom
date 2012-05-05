module DICOM

  # This class handles DICOM files that have been received through network communication.
  #
  # === Notes
  #
  # The purpose of this class is to make it as easy as possible for users to customize the way
  # DICOM files are handled when they are received through the network.
  #
  # The default behaviour is to save the files to disk using a folder structure determined by a  few select tags of the DICOM file.
  #
  # Some suggested alternatives for user customization:
  # * Analyzing tags and/or image data to determine further actions.
  # * Modify the DICOM object before it is saved to disk.
  # * Modify the folder structure in which DICOM files are saved to disk.
  # * Store DICOM contents in a database (highly relevant if you are building a Ruby on Rails DICOM application).
  # * Retransmit the DICOM object to another network destination using the DClient class.
  # * Write information to a log file.
  #
  class FileHandler

    # Saves a single DICOM object to file.
    # Returns a status message stating where the file has been saved.
    #
    # Modify this method if you want to change the way your server saves incoming files.
    #
    # === Notes
    #
    # As default, files will be saved with the following path:
    # <tt> path_prefix/<PatientID>/<StudyDate>/<Modality>/ </tt>
    #
    # === Parameters
    #
    # * <tt>path_prefix</tt> -- String. Specifies the root path of the DICOM storage.
    # * <tt>dcm</tt> -- A DObject instance which will be written to file.
    # * <tt>transfer_syntax</tt> -- String. Specifies the transfer syntax that will be used to write the DICOM file.
    #
    def self.save_file(path_prefix, dcm, transfer_syntax)
      # File name is set using the SOP Instance UID:
      file_name = dcm.value("0008,0018") || "missing_SOP_UID"
      extension = ".dcm"
      folders = Array.new(3)
      folders[0] = dcm.value("0010,0020") || "PatientID"
      folders[1] = dcm.value("0008,0020") || "StudyDate"
      folders[2] = dcm.value("0008,0060") || "Modality"
      local_path = folders.join(File::SEPARATOR) + File::SEPARATOR + file_name
      full_path = path_prefix + local_path + extension
      # Save the DICOM object to disk:
      dcm.write(full_path, :transfer_syntax => transfer_syntax)
      message = [:info, "DICOM file saved to: #{full_path}"]
      return message
    end

    # Handles the reception of a series of DICOM objects which are received in a single association.
    #
    # Modify this method if you want to change the way your server handles incoming file series.
    #
    # === Notes
    #
    # Default action: Pass each file to the class method which saves files to disk.
    #
    # === Parameters
    #
    # * <tt>path</tt> -- String. Specifies the root path of the DICOM storage.
    # * <tt>objects</tt> -- An array containing the DObject instances which were received.
    # * <tt>transfer_syntaxes</tt> -- An array containing the transfer syntaxes belonging to the received objects.
    #
    def self.receive_files(path, objects, transfer_syntaxes)
      all_success = true
      successful, too_short, parse_fail, handle_fail = 0, 0, 0, 0
      total = objects.length
      message = nil
      messages = Array.new
      # Process each DICOM object:
      objects.each_index do |i|
        if objects[i].length > 8
          # Temporarily increase the log threshold to suppress messages from the DObject class:
          server_level = DICOM.logger.level
          DICOM.logger.level = Logger::FATAL
          # Parse the received data string and load it to a DICOM object:
          dcm = DObject.parse(objects[i], :no_meta => true, :syntax => transfer_syntaxes[i])
          # Reset the logg threshold:
          DICOM.logger.level = server_level
          if dcm.read?
            begin
              message = self.save_file(path, dcm, transfer_syntaxes[i])
              successful += 1
            rescue
              handle_fail += 1
              all_success = false
              messages << [:error, "Saving file failed!"]
            end
          else
            parse_fail += 1
            all_success = false
            messages << [:error, "Invalid DICOM data encountered: The received string was not parsed successfully."]
          end
        else
          too_short += 1
          all_success = false
          messages << [:error, "Invalid data encountered: The received string was too small to contain any DICOM data."]
        end
      end
      # Create a summary status message, when multiple files have been received:
      if total > 1
        if successful == total
          messages << [:info, "All #{total} DICOM files received successfully."]
        else
          if successful == 0
            messages << [:warn, "All #{total} received DICOM files failed!"]
          else
            messages << [:warn, "Only #{successful} of #{total} DICOM files received successfully!"]
          end
        end
      else
        messages = [message] if all_success
      end
      return all_success, messages
    end

  end
end