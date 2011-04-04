require File.dirname(__FILE__) + '/../lib/dicom'

require 'narray'

RSpec.configure do |config|
  config.mock_with :mocha
end

# Defining constants for the sample DICOM files that are used in the specification,
# while suppressing the annoying warnings when these constants are re-initialized.
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
  DICOM::DCM_IMPLICIT_MR_16BIT_MONO2 = File.dirname(__FILE__) + '/support/sample_implicit_mr_16bit_mono2.dcm'
  DICOM::DCM_NO_HEADER_IMPLICIT_MR_16BIT_MONO2 = File.dirname(__FILE__) + '/support/sample_no-header_implicit_mr_16bit_mono2.dcm'
  DICOM::DCM_EXPLICIT_BIG_ENDIAN_US_8BIT_RBG = File.dirname(__FILE__) + '/support/sample_explicit-big-endian_us_8bit_rgb.dcm'
  DICOM::DCM_IMPLICIT_NO_HEADER_OT_8BIT_PAL = File.dirname(__FILE__) + '/support/sample_no-header_implicit_ot_8bit_pal.dcm'
  DICOM::DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2 = File.dirname(__FILE__) + '/support/sample_explicit_mr_jpeg-lossy_mono2.dcm'
  DICOM::DCM_EXPLICIT_US_RLE_PAL_MULTIFRAME = File.dirname(__FILE__) + '/support/sample_explicit_us_rle_pal_multiframe.dcm'
  # Directory for writing temporary files:
  DICOM::TMPDIR = "tmp/"
end

# Create a directory for temporary files (and delete the directory if it already exists):
require 'fileutils'
FileUtils.rmtree(DICOM::TMPDIR) if File.directory?(DICOM::TMPDIR)
FileUtils.mkdir(DICOM::TMPDIR)