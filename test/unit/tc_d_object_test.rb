require File.dirname(__FILE__) + '/../test_helper'

class TC_DObjectTest < Test::Unit::TestCase

  def setup
    @obj0 = DObject.new(nil) # Empty object
    @obj = DObject.new(DICOM_TEST_FILE1) # "Normal" way of loading a DICOM file.
    # Load the same file as above, but from a binary string:
    file = File.new(DICOM_TEST_FILE1, "rb")
    str = file.read
    file.close
    @obj_bin = DObject.new(str, :bin => true)
  end

  # Tests a small sample of values in the DICOM object.
  def test_value
    assert_nil(@obj0.value("0010,0010"), "Should return nil as there are no tags yet in the DObject.")
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
    assert_equal("Anonymized", @obj_bin.value("0010,0010"), "Checking the validity of an ordinary string value.")
  end

  def test_count
    assert_equal(0, @obj0.count, "The empty DICOM object contains 0 tags.")
    assert_equal(0, @obj0.count_all, "The empty DICOM object contains 0 tags.")
    assert_equal(97, @obj.count, "The DICOM file contains 97 top level tags.")
    assert_equal(123, @obj.count_all, "The DICOM file contains 123 tags in total.")
    # This fails, and so needs to be investigated:
    #assert_equal(97, @obj_bin.count, "The DICOM file contains 97 top level tags.")
    #assert_equal(123, @obj_bin.count_all, "The DICOM file contains 123 tags in total.")
  end

  def test_information
    assert_instance_of(Array, @obj0.information)
    assert_instance_of(Array, @obj.information)
  end

  def test_print
    printed0 = @obj0.print
    assert_instance_of(Array, printed0)
    assert_equal(0, printed0.length)
    printed = @obj.print
    assert_instance_of(Array, printed)
    assert_equal(123, printed.length)
  end

end