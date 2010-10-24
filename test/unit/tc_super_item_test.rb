require File.dirname(__FILE__) + '/../test_helper'

class TC_SuperItemTest < Test::Unit::TestCase

  def setup
    @obj0 = DObject.new(nil) # Empty object
    @obj1 = DObject.new(DICOM_TEST_FILE1) # Compressed, monochrome2, single frame MR image
    @obj2 = DObject.new(DICOM_TEST_FILE2) # 16 bit, monochrome2, single frame MR image
  end

  def test_color?
    assert_equal(false, @obj1.color?)
    assert_equal(false, @obj2.color?)
  end

  def test_compression?
    assert(@obj1.compression?)
    assert_equal(false, @obj2.compression?)
  end

  def test_decode_pixels
    assert_raise(RuntimeError) {@obj0.decode_pixels("0000")} # Should raise error as the DICOM object don't have enough information to properly decode pixels.
    assert_raise(ArgumentError) {@obj2.decode_pixels(nil)} # Should raise error as the argument must be a String.
    assert_instance_of(Array, @obj2.decode_pixels("0000"), "Decoded pixel values should be returned in an array.")
    assert_equal(2, @obj2.decode_pixels("0000").length, "The given string should result in an array of two numbers for a DICOM object with 16-bit pixel values.")
  end

  def test_encode_pixels
    assert_raise(RuntimeError) {@obj0.encode_pixels("0000")} # Should raise error as the DICOM object don't have enough information to properly encode pixels.
    assert_raise(ArgumentError) {@obj2.encode_pixels(nil)} # Should raise error as the argument must be an Array.
    assert_instance_of(String, @obj2.encode_pixels([0,0]), "Encoded pixel values should be returned as a string.")
    assert_equal(4, @obj2.encode_pixels([0,0]).length, "The given array should result in a string of four characters for a DICOM object with 16-bit pixel values.")
  end

end