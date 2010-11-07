$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'narray'
require 'test/unit'

require File.dirname(__FILE__) + '/../lib/dicom'
include DICOM

DICOM_TEST_FILE1 = File.dirname(__FILE__) + '/sample_explicit_mr_jpeg-lossy_mono2.dcm'
DICOM_TEST_FILE2 = File.dirname(__FILE__) + '/sample_implicit_mr_16bit_mono2.dcm'