require File.dirname(__FILE__) + '/../lib/dicom'

RSpec.configure do |config|
  config.mock_with :mocha
end

# Defining constants for the sample DICOM files that are used in the specification,
# while suppressing the annoying warnings when these constants are initialized.
module Kernel
  def suppress_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    result = yield
    $VERBOSE = original_verbosity
    return result
  end
end

suppress_warnings do
  # Sample DICOM files:
  # Uncompressed:
  DICOM::DCM_IMPLICIT_MR_16BIT_MONO2 = 'samples/implicit_mr_16bit_mono2.dcm'
  DICOM::DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2 = 'samples/no-header_implicit_mr_16bit_mono2.dcm'
  DICOM::DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG = 'samples/explicit-big-endian_us_8bit_rgb.dcm'
  DICOM::DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL = 'samples/no-header_implicit_ot_8bit_pal.dcm'
  DICOM::DCM_EXPLICIT_MR_16BIT_MONO2_NON_SQUARE_PAL_ICON = 'samples/explicit_mr_16bit_mono2_non-square_pal_icon.dcm'
  DICOM::DCM_EXPLICIT_RTDOSE_16BIT_MONO2_3D_VOLUME = 'samples/explicit_rtdose_16bit_mono2_3d-volume.dcm'
  # With compression:
  DICOM::DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2 = 'samples/explicit_mr_jpeg-lossy_mono2.dcm'
  DICOM::DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME = 'samples/explicit_us_rle_pal_multiframe.dcm'
  DICOM::DCM_EXPLICIT_MR_RLE_MONO2 = 'samples/explicit_mr_rle_mono2.dcm'
  DICOM::DCM_EXPLICIT_CT_JPEG_LOSSLESS_NH_MONO2 = 'samples/explicit_ct_jpeg-lossless-nh_mono2.dcm'
  DICOM::DCM_IMPLICIT_US_JPEG2K_LOSSLESS_MONO2_MULTIFRAME = 'samples/implicit_us_jpeg2k-lossless-mono2-multiframe.dcm'
  # Directory for writing temporary files:
  DICOM::TMPDIR = "tmp/"
  DICOM::LOGDIR = DICOM::TMPDIR + "logs/"
end

# Create a directory for temporary files (and delete the directory if it already exists):
require 'fileutils'
FileUtils.rmtree(DICOM::TMPDIR) if File.directory?(DICOM::TMPDIR)
FileUtils.mkdir(DICOM::TMPDIR)
FileUtils.mkdir(DICOM::LOGDIR)