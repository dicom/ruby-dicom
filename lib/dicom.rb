# Core library:
require 'dicom/DClient'
require 'dicom/Dictionary'
require 'dicom/DLibrary'
require 'dicom/DObject'
require 'dicom/DRead'
require 'dicom/DServer'
require 'dicom/DWrite'
require 'dicom/Link'
require 'dicom/Stream'
# Extended library:
require 'dicom/Anonymizer'
# Extensions to the Ruby library:
require 'dicom/ruby_extensions'

# Ruby DICOM version string:
DICOM::VERSION = "0.6.1"

# Load the DICOM Library class (dictionary):
DICOM::LIBRARY =  DICOM::DLibrary.new

# Ruby DICOM implementation name and uid:
DICOM::NAME = "RUBY_DICOM_" + DICOM::VERSION
DICOM::UID = "1.2.826.0.1.3680043.8.641"