require File.dirname(__FILE__) + '/../test_helper'

class DObjectTest < Test::Unit::TestCase
  def setup
    @dcm = DObject.new(DICOM_TEST_FILE)
  end
  
  def test_should_be_valid_dobject
    
    assert_instance_of(DObject, @dcm, "Should be a valid instance.")
    assert(true, @dcm.read_success)
  end
  
  def test_read_correct_modality
    
    assert_equal("MR Image Storage", @dcm.modality)
  end
  
  def test_tags
    
    assert_equal(@dcm.names.length, @dcm.tags.length)
    assert_equal(@dcm.names.length, @dcm.values.length)
    assert_equal(@dcm.tags.length, @dcm.values.length)
  end
  
  # Test a small sample of values to expect
  def test_get_value
    
    assert_equal("Anonymized", @dcm.get_value("0010,0010"))                 # Patient Name
    assert_equal("MR", @dcm.get_value("0008,0060"))                         # Modality
    assert_equal("20090408", @dcm.get_value("0008,0022"))                   # Acquisition Date
    assert_instance_of(Array, @dcm.get_value("0008,0008", :array => true))  # Image Type
  end
  
end