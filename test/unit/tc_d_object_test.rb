require File.dirname(__FILE__) + '/../test_helper'

class TC_DObjectTest < Test::Unit::TestCase

  def setup
    @obj = DObject.new(DICOM_TEST_FILE)
  end

  def test_should_be_valid_dobject
    assert_instance_of(DObject, @obj, "Should be a valid instance regardless of DICOM file parse success.")
    assert(@obj.read_success, "Should return true when DICOM file has been successfully parsed.")
  end

  # Tests a small sample of values in the DICOM object.
  def test_value
    assert_equal("Anonymized", @obj.value("0010,0010"), "Checking the validity of an ordinary string value.")
    assert_equal(192, @obj.value("0002,0000"), "A tag containing an unsigned long value should be returned as a proper Fixnum.")
    assert_equal("PFP", @obj.value("0018,0022"), "String values of odd length should be properly right-stripped when returned.")
    assert_instance_of(String, @obj.value("0018,1310"), "For tags containing multiple numbers, the numbers should be returned in string, separated by double backslash.")
    assert_equal(4, @obj.value("0018,1310").split("\\").length, "For a tag containing 4 numbers, a 4-element array should be returned when string splitted.")
    assert_equal(256, @obj.value("0018,1310").split("\\")[1].to_i, "For tags containing multiple numbers, check that the correct number is returned when extracting it according to the proper procedure..")
    assert_nil(@obj.value("1111,1111"), "Should return nil for valid tag not present in DObject.")
    assert_nil(@obj.value("abcg,0000"), "Should return nil when an invalid tag (non-hex character) is passed.")
    assert_nil(@obj.value("0010,00000"), "Should return nil when an invalid tag (wrong format) is passed.")
    assert_raise(RuntimeError) {@obj.value("7FE0,0010")} # For parent elements (like when pixel data is encapsulated), there is no value defined and an error is raised.
  end

  def test_count
    assert_equal(97, @obj.count, "The DICOM file contains 97 top level tags.")
    assert_equal(123, @obj.count_all, "The DICOM file contains 123 tags in total.")
  end

  def test_transfer_syntax
    assert_equal("1.2.840.10008.1.2.4.50", @obj.transfer_syntax)
  end

  def test_attributes
    assert_nil(@obj.write_success, "Should be nil when a file write has not been attempted yet.")
    assert_instance_of(Stream, @obj.stream)
    assert_nil(@obj.parent, "A DObject instance is the top level and has no parent (should be nil).")
    assert_equal(0, @obj.errors.length)
  end

  def test_information
    assert_instance_of(Array, @obj.information)
  end

  def test_print
    printed = @obj.print
    assert_instance_of(Array, printed)
    assert_equal(123, printed.length)
  end

  # This method's assertions fail for some reason. Needs to be investigated further.
=begin
  def test_encode_segments
    assert_equal(1, @obj.encode_segments(16384).length)
    assert_equal(2, @obj.encode_segments(8192).length)
    assert_equal(3, @obj.encode_segments(4096).length)
    assert_equal(6, @obj.encode_segments(2048).length)
    assert_equal(11, @obj.encode_segments(1024).length)
  end
=end

  def test_write_and_read
    test_write = DICOM_TEST_FILE+"_WRITETEST.dcm"
    @obj.write(test_write)
    assert(@obj.write_success, "Should return true when a DObject instance has been successfully written to file.")
    obj_reloaded = DObject.new(test_write)
    assert_instance_of(DObject, obj_reloaded, "Should be a valid instance regardless of DICOM file parse success.")
    assert(obj_reloaded.read_success, "Should return true when DICOM file has been successfully parsed.")
    # Clean up:
    File.delete(test_write)
  end

end