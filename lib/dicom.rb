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
# Ruby library extensions:
require 'dicom/ruby_extensions'

# Ruby DICOM version string:
DICOM::VERSION = "0.6.1"