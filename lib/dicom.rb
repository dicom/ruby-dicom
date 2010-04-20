# Core library:
# Super classes/modules (which needs to be loaded in a proper sequence):
require 'dicom/SuperParent'
require 'dicom/SuperItem'
require 'dicom/Elements'
# Subclasses and independent classes:
require 'dicom/DataElement'
require 'dicom/DClient'
require 'dicom/Dictionary'
require 'dicom/DLibrary'
require 'dicom/DObject'
require 'dicom/DRead'
require 'dicom/DServer'
require 'dicom/DWrite'
require 'dicom/FileHandler'
require 'dicom/Item'
require 'dicom/Link'
require 'dicom/Sequence'
require 'dicom/Stream'
# Extensions to the Ruby library:
require 'dicom/ruby_extensions'

# Extended library:
require 'dicom/Anonymizer'


# Ruby DICOM version string:
DICOM::VERSION = "0.7.5b"

# Ruby DICOM implementation name and uid:
DICOM::NAME = "RUBY_DICOM_" + DICOM::VERSION
DICOM::UID = "1.2.826.0.1.3680043.8.641"

# Item tag:
DICOM::ITEM_TAG = "FFFE,E000"
# Item related tags (includes both types of delimitation items):
DICOM::ITEM_TAGS = ["FFFE,E000", "FFFE,E00D", "FFFE,E0DD"]
# Delimiter tags (includes both types of delimitation items):
DICOM::DELIMITER_TAGS = ["FFFE,E00D", "FFFE,E0DD"]

# VR used for the item elements:
DICOM::ITEM_VR = "()"

# Pixel tag:
DICOM::PIXEL_TAG = "7FE0,0010"

# Load the DICOM Library class (dictionary):
DICOM::LIBRARY =  DICOM::DLibrary.new