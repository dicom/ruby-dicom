module DICOM

  # Ruby DICOM's registered DICOM UID root (Implementation Class UID).
  UID_ROOT = "1.2.826.0.1.3680043.8.641"
  # Ruby DICOM name & version (max 16 characters).
  NAME = "RUBY-DCM_" + DICOM::VERSION

  # Item tag.
  ITEM_TAG = "FFFE,E000"
  # All Item related tags (includes both types of delimitation items).
  ITEM_TAGS = ["FFFE,E000", "FFFE,E00D", "FFFE,E0DD"]
  # Item delimiter tag.
  ITEM_DELIMITER = "FFFE,E00D"
  # Sequence delimiter tag.
  SEQUENCE_DELIMITER = "FFFE,E0DD"
  # All delimiter tags.
  DELIMITER_TAGS = ["FFFE,E00D", "FFFE,E0DD"]

  # The VR used for the item elements.
  ITEM_VR = "  "

  # Pixel tag.
  PIXEL_TAG = "7FE0,0010"
  # Name of the pixel tag when holding encapsulated data.
  ENCAPSULATED_PIXEL_NAME = "Encapsulated Pixel Data"
  # Name of encapsulated items.
  PIXEL_ITEM_NAME = "Pixel Data Item"

  # File meta group.
  META_GROUP = "0002"

  # Group length element.
  GROUP_LENGTH = "0000"

  # Implicit, little endian (the default transfer syntax).
  IMPLICIT_LITTLE_ENDIAN = "1.2.840.10008.1.2"
  # Explicit, little endian transfer syntax.
  EXPLICIT_LITTLE_ENDIAN = "1.2.840.10008.1.2.1"
  # Explicit, big endian transfer syntax.
  EXPLICIT_BIG_ENDIAN = "1.2.840.10008.1.2.2"

  # Verification SOP class UID.
  VERIFICATION_SOP = "1.2.840.10008.1.1"
  # Application context SOP class UID.
  APPLICATION_CONTEXT = "1.2.840.10008.3.1.1.1"

  # Network transmission successful.
  SUCCESS = 0
  # Network proposition accepted.
  ACCEPTANCE = 0
  # Presentation context rejected by abstract syntax.
  ABSTRACT_SYNTAX_REJECTED = 3
  # Presentation context rejected by transfer syntax.
  TRANSFER_SYNTAX_REJECTED = 4

  # Some network command element codes:
  C_STORE_RQ = 1 # (encodes to 0001H as US)
  C_GET_RQ = 16 # (encodes to 0010H as US)
  C_FIND_RQ = 32 # (encodes to 0020H as US)
  C_MOVE_RQ = 33 # (encodes to 0021H as US)
  C_ECHO_RQ = 48 # (encodes to 0030 as US)
  C_CANCEL_RQ = 4095 # (encodes to 0FFFH as US)
  C_STORE_RSP = 32769 # (encodes to 8001H as US)
  C_GET_RSP = 32784 # (encodes to 8010H as US)
  C_FIND_RSP = 32800 # (encodes to 8020H as US)
  C_MOVE_RSP = 32801 # (encodes to 8021H as US)
  C_ECHO_RSP = 32816 # (encodes to 8030H as US)
  NO_DATA_SET_PRESENT = 257 # (encodes to 0101H as US)
  DATA_SET_PRESENT = 1
  DEFAULT_MESSAGE_ID = 1

  # The network communication flags:
  DATA_MORE_FRAGMENTS = "00"
  COMMAND_MORE_FRAGMENTS = "01"
  DATA_LAST_FRAGMENT = "02"
  COMMAND_LAST_FRAGMENT = "03"

  # Network communication PDU types:
  PDU_ASSOCIATION_REQUEST = "01"
  PDU_ASSOCIATION_ACCEPT = "02"
  PDU_ASSOCIATION_REJECT = "03"
  PDU_DATA = "04"
  PDU_RELEASE_REQUEST = "05"
  PDU_RELEASE_RESPONSE = "06"
  PDU_ABORT = "07"

  # Network communication item types:
  ITEM_APPLICATION_CONTEXT = "10"
  ITEM_PRESENTATION_CONTEXT_REQUEST = "20"
  ITEM_PRESENTATION_CONTEXT_RESPONSE = "21"
  ITEM_ABSTRACT_SYNTAX = "30"
  ITEM_TRANSFER_SYNTAX = "40"
  ITEM_USER_INFORMATION = "50"
  ITEM_MAX_LENGTH = "51"
  ITEM_IMPLEMENTATION_UID = "52"
  ITEM_MAX_OPERATIONS_INVOKED = "53"
  ITEM_ROLE_NEGOTIATION = "54"
  ITEM_IMPLEMENTATION_VERSION = "55"

  # Varaibles used to determine endianness.
  x = 0xdeadbeef
  endian_type = {
    Array(x).pack("V*") => false, # Little
    Array(x).pack("N*") => true   # Big
  }
  # System (CPU) Endianness.
  CPU_ENDIAN = endian_type[Array(x).pack("L*")]

  # Transfer Syntaxes (taken from the DICOM Specification PS 3.5, Chapter 10).

  # General
  TXS_IMPLICIT_LITTLE_ENDIAN            = '1.2.840.10008.1.2'      # also defined as IMPLICIT_LITTLE_ENDIAN, default transfer syntax
  TXS_EXPLICIT_LITTLE_ENDIAN            = '1.2.840.10008.1.2.1'    # also defined as EXPLICIT_LITTLE_ENDIAN
  TXS_EXPLICIT_BIG_ENDIAN               = '1.2.840.10008.1.2.2'    # also defined as EXPLICIT_BIG_ENDIAN

  # TRANSFER SYNTAXES FOR ENCAPSULATION OF ENCODED PIXEL DATA
  TXS_JPEG_BASELINE                     = '1.2.840.10008.1.2.4.50'
  TXS_JPEG_EXTENDED                     = '1.2.840.10008.1.2.4.51'
  TXS_JPEG_LOSSLESS_NH                  = '1.2.840.10008.1.2.4.57' # NH: non-hirarchical
  TXS_JPEG_LOSSLESS_NH_FOP              = '1.2.840.10008.1.2.4.70' # NH: non-hirarchical, FOP: first-order prediction

  TXS_JPEG_LS_LOSSLESS                  = '1.2.840.10008.1.2.4.80'
  TXS_JPEG_LS_NEAR_LOSSLESS             = '1.2.840.10008.1.2.4.81'

  TXS_JPEG_2000_PART1_LOSSLESS          = '1.2.840.10008.1.2.4.90'
  TXS_JPEG_2000_PART1_LOSSLESS_OR_LOSSY = '1.2.840.10008.1.2.4.91'
  TXS_JPEG_2000_PART2_LOSSLESS          = '1.2.840.10008.1.2.4.92'
  TXS_JPEG_2000_PART2_LOSSLESS_OR_LOSSY = '1.2.840.10008.1.2.4.93'

  TXS_MPEG2_MP_ML                       = '1.2.840.10008.1.2.4.100'
  TXS_MPEG2_MP_HL                       = '1.2.840.10008.1.2.4.101'

  TXS_DEFLATED_LITTLE_ENDIAN            = '1.2.840.10008.1.2.1.99'  # ZIP Compression

  TXS_JPIP                              = '1.2.840.10008.1.2.4.94'
  TXS_JPIP_DEFLATE                      = '1.2.840.10008.1.2.4.95'

  TXS_RLE                               = '1.2.840.10008.1.2.5'


  # Photometric Interpretations
  # Taken from DICOM Specification PS 3.3 C.7.6.3.1.2 Photometric Interpretation

  PI_MONOCHROME1     = 'MONOCHROME1'
  PI_MONOCHROME2     = 'MONOCHROME2'
  PI_PALETTE_COLOR   = 'PALETTE COLOR'
  PI_RGB             = 'RGB'
  PI_YBR_FULL        = 'YBR_FULL'
  PI_YBR_FULL_422    = 'YBR_FULL_422 '
  PI_YBR_PARTIAL_422 = 'YBR_PARTIAL_422'
  PI_YBR_PARTIAL_420 = 'YBR_PARTIAL_420'
  PI_YBR_ICT         = 'YBR_ICT'
  PI_YBR_RCT         = 'YBR_RCT'

  # Retired Photometric Interpretations, are those needed to be supported?
  PI_HSV             = 'HSV'
  PI_ARGB            = 'ARGB'
  PI_CMYK            = 'CMYK'

  # The relationship between DICOM Character Set and Encoding name.
  ENCODING_NAME = {
    'ISO_IR 100' => 'ISO-8859-1',
    'ISO_IR 101' => 'ISO-8859-2',
    'ISO_IR 109' => 'ISO-8859-3',
    'ISO_IR 110' => 'ISO-8859-4',
    'ISO_IR 144' => 'ISO-8859-5',
    'ISO_IR 127' => 'ISO-8859-6',
    'ISO_IR 126' => 'ISO-8859-7',
    'ISO_IR 138' => 'ISO-8859-8',
    'ISO_IR 148' => 'ISO-8859-9',
    'ISO_IR 13'  => 'JIS_X0201',
    'ISO_IR 166' => 'ISO-8859-11',
    'GB18030'    => 'GB18030',
    'ISO_IR 192' => 'UTF-8'
  }
  ENCODING_NAME.default = 'ASCII-8BIT'

  # The type conversion (method) used for the various value representations.
  VALUE_CONVERSION = {
    'BY' => :to_i,
    'US' => :to_i,
    'SS' => :to_i,
    'UL' => :to_i,
    'SL' => :to_i,
    'OB' => :to_i,
    'OW' => :to_i,
    'OF' => :to_f,
    'FL' => :to_f,
    'FD' => :to_f,
    'AT' => :to_s,
    'AE' => :to_s,
    'AS' => :to_s,
    'CS' => :to_s,
    'DA' => :to_s,
    'DS' => :to_s,
    'DT' => :to_s,
    'IS' => :to_s,
    'LO' => :to_s,
    'LT' => :to_s,
    'PN' => :to_s,
    'SH' => :to_s,
    'ST' => :to_s,
    'TM' => :to_s,
    'UI' => :to_s,
    'UT' => :to_s
  }
  VALUE_CONVERSION.default = :to_s

end

