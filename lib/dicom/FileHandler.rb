#    Copyright 2010 Christoffer Lervag

# The purpose of this file is to make it very easy for users to customise the way
# DICOM files are handled when they are received through the network.
# The default behaviour is to save the file to disk using a folder structure determined by the file's DICOM tags.
# Some suggested alternatives:
# - Analyzing tags and/or image data to determine further actions.
# - Modify the DICOM object before it is saved to disk.
# - Modify the folder structure in which DICOM files are saved to disk.
# - Store DICOM contents in a database (highly relevant if you are building a Ruby on Rails application).
# - Retransmit the DICOM object to another network destination using the DClient class.

module DICOM

  # This class handles DICOM files that have been received through network communication.
  class FileHandler

    # Handles the reception of a DICOM file.
    # Default action: Save to disk.
    # Modify this method if you want a different behaviour!
    def self.receive_file(obj, path_prefix, transfer_syntax)
      # Did we receive a valid DICOM file?
      if obj.read_success
        # File name will be equal to the SOP Instance UID
        file_name = obj.get_value("0008,0018") || "no_SOP_UID.dcm"
        # File will be saved with the following path:
        # path_prefix/<PatientID>/<StudyDate>/<Modality>/
        folders = Array.new(3)
        folders[0] = obj.get_value("0010,0020") || "PatientID"
        folders[1] = obj.get_value("0008,0020") || "StudyDate"
        folders[2] = obj.get_value("0008,0060") || "Modality"
        local_path = folders.join(File::SEPARATOR) + File::SEPARATOR + file_name
        full_path = path_prefix + local_path
        # Save the DICOM object to disk:
        obj.write(full_path, transfer_syntax)
        # As the file has been received successfully, return a 'success message':
        message = "DICOM file saved to: #{full_path}"
      else
        # Received data was not successfully read as a DICOM file.
        message = false
      end
      return message
    end

  end # of class
end # of module