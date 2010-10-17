$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'test/unit'

require File.dirname(__FILE__) + '/../lib/dicom'
include DICOM

DICOM_TEST_FILE = File.dirname(__FILE__) + '/test.dcm'