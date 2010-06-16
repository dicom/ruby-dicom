#    Copyright 2010 Christoffer Lervag

# This file contains module constants used by the Ruby DIOCOM library:
module DICOM

  # Ruby DICOM version string:
  VERSION = "0.7.7b"

  # Ruby DICOM implementation name and uid:
  NAME = "RUBY_DCM_" + DICOM::VERSION
  UID = "1.2.826.0.1.3680043.8.641"

  # Item tag:
  ITEM_TAG = "FFFE,E000"
  # Item related tags (includes both types of delimitation items):
  ITEM_TAGS = ["FFFE,E000", "FFFE,E00D", "FFFE,E0DD"]
  # Delimiter tags (includes both types of delimitation items):
  ITEM_DELIMITER = "FFFE,E00D"
  SEQUENCE_DELIMITER = "FFFE,E0DD"
  DELIMITER_TAGS = ["FFFE,E00D", "FFFE,E0DD"]

  # VR used for the item elements:
  ITEM_VR = "  "

  # Pixel tag:
  PIXEL_TAG = "7FE0,0010"
  ENCAPSULATED_PIXEL_NAME = "Encapsulated Pixel Data"
  PIXEL_ITEM_NAME = "Pixel Data Item"

  # File Meta Group:
  META_GROUP = "0002"

  # Group length element:
  GROUP_LENGTH = "0000"

  # A few commonly used transfer syntaxes:
  IMPLICIT_LITTLE_ENDIAN = "1.2.840.10008.1.2"
  EXPLICIT_LITTLE_ENDIAN = "1.2.840.10008.1.2.1"
  EXPLICIT_BIG_ENDIAN = "1.2.840.10008.1.2.2"
  
  # SOP Class of special interest:
  VERIFICATION_SOP = "1.2.840.10008.1.1"
  APPLICATION_CONTEXT = "1.2.840.10008.3.1.1.1"
  
  # Network communication result codes:
  ACCEPTANCE = 0
  ABSTRACT_SYNTAX_REJECTED = 3
  TRANSFER_SYNTAX_REJECTED = 4
  
  # Network transmission result codes:
  SUCCESS = 0
  
  # Network Command Element codes:
  C_STORE_RQ = 1 # (encodes to 0001H as US)
  C_GET_RQ = 16
  C_FIND_RQ = 32
  C_MOVE_RQ = 33
  C_STORE_RSP = 32769 # (encodes to 8001H as US)
  NO_DATA_SET_PRESENT = 257 # (encodes to 0101H as US)
  DEFAULT_MESSAGE_ID = 1
  
  # Flags:
  DATA_MORE_FRAGMENTS = "00"
  COMMAND_MORE_FRAGMENTS = "01"
  DATA_LAST_FRAGMENT = "02"
  COMMAND_LAST_FRAGMENT = "03"
  
  # PDUs:
  PDU_ASSOCIATION_REQUEST = "01"
  PDU_ASSOCIATION_ACCEPT = "02"
  PDU_ASSOCIATION_REJECT = "03"
  PDU_DATA = "04"
  PDU_RELEASE_REQUEST = "05"
  PDU_RELEASE_RESPONSE = "06"
  PDU_ABORT = "07"

  # System (CPU) Endianness:
  x = 0xdeadbeef
  endian_type = {
    Array(x).pack("V*") => false, # Little
    Array(x).pack("N*") => true   # Big
  }
  CPU_ENDIAN = endian_type[Array(x).pack("L*")]

  # Load the DICOM Library class (dictionary):
  LIBRARY =  DICOM::DLibrary.new

end