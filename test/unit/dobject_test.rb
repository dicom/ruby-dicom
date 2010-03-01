require File.dirname(__FILE__) + '/../test_helper'

class DObjectTest < Test::Unit::TestCase
  def test_should_be_valid_dicom
    d = DObject.new(dicom_test_file
    assert_valid d
  end
end