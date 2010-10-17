require File.dirname(__FILE__) + '/../test_helper'

class TC_DObjectTest < Test::Unit::TestCase

  def setup
    @obj = DObject.new(DICOM_TEST_FILE)
  end

  def test_should_be_valid_dobject

    assert_instance_of(DObject, @obj, "Should be a valid instance.")
    assert(true, @obj.read_success)
  end

  # Test a small sample of values to expect
  def test_get_value

    assert_equal("Anonymized", @obj.value("0010,0010")) # Patient's Name
    assert_equal("MR", @obj.value("0008,0060")) # Modality
    assert_equal("20090408", @obj.value("0008,0022")) # Acquisition Date
  end

end