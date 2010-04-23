#    Copyright 2010 Christoffer Lervag

# This file contains module constants used by the Ruby DIOCOM library:

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
DICOM::ITEM_VR = "  "

# Pixel tag:
DICOM::PIXEL_TAG = "7FE0,0010"
DICOM::ENCAPSULATED_PIXEL_NAME = "Encapsulated Pixel Data"
DICOM::PIXEL_ITEM_NAME = "Pixel Data Item"

# System (CPU) Endianness:
x = 0xdeadbeef
endian_type = {
  Array(x).pack("V*") => false, # Little
  Array(x).pack("N*") => true   # Big
}
DICOM::CPU_ENDIAN = endian_type[Array(x).pack("L*")]

# Load the DICOM Library class (dictionary):
DICOM::LIBRARY =  DICOM::DLibrary.new