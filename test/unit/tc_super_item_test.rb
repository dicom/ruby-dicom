require File.dirname(__FILE__) + '/../test_helper'

class TC_SuperItemTest < Test::Unit::TestCase

  def setup
    @obj0 = DObject.new(nil) # Empty object
    @obj1 = DObject.new(DICOM_TEST_FILE1) # Compressed, monochrome2, single frame MR image
    @obj2 = DObject.new(DICOM_TEST_FILE2) # 16 bit, monochrome2, single frame MR image
  end

  def test_color?
    assert_equal(false, @obj0.color?)
    assert_equal(false, @obj1.color?)
    assert_equal(false, @obj2.color?)
  end

  def test_compression?
    assert_equal(false, @obj0.compression?)
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

  def test_get_image
    assert_nil(@obj0.get_image, "A DObject without pixel data should return nil here.")
    assert_equal(false, @obj1.get_image, "When failing to unpack compressed pixel data, false should be returned (This test needs to be changed if compression is successfully implemented at some stage).")
    assert_instance_of(Array, @obj2.get_image, "The result from get_image() should be a Ruby Array of pixel data.")
    assert_equal(65536, @obj2.get_image.length, "The pixel data array for this DICOM object should have 65536 elements (256*256 pixels).")
    assert_equal(1024, @obj2.get_image.min, "Minimum pixel data value should be 1024.")
    assert_equal(1284, @obj2.get_image.max, "Minimum pixel data value should be 1284.")
    assert_equal(1024, @obj2.get_image(:remap => true).min, "Minimum pixel data value should still be 1024, as there is no intercept/slope.")
    assert_equal(1284, @obj2.get_image(:remap => true).max, "Minimum pixel data value should be 1284, as there is no intercept/slope.")
    assert_equal(1053, @obj2.get_image(:level => true).min, "Minimum pixel data value should be 1053 (as a result of default center/width remapping).")
    assert_equal(1137, @obj2.get_image(:level => true).max, "Minimum pixel data value should be 1137 (as a result of default center/width remapping).")
    assert_equal(1053, @obj2.get_image(:level => true, :narray => true).min, "Minimum pixel data value should be 1053 (as a result of default center/width remapping).")
    assert_equal(1137, @obj2.get_image(:level => true, :narray => true).max, "Minimum pixel data value should be 1137 (as a result of default center/width remapping).")
    assert_equal(1050, @obj2.get_image(:level => [1100, 100]).min, "Minimum pixel data value should be 1050 (as a result of the requested center/width remapping).")
    assert_equal(1150, @obj2.get_image(:level => [1100, 100]).max, "Minimum pixel data value should be 1150 (as a result of the requested center/width remapping).")
    assert_equal(1050, @obj2.get_image(:level => [1100, 100], :narray => true).min, "Minimum pixel data value should be 1050 (as a result of the requested center/width remapping).")
    assert_equal(1150, @obj2.get_image(:level => [1100, 100], :narray => true).max, "Minimum pixel data value should be 1150 (as a result of the requested center/width remapping).")
  end

  def test_get_image_narray
    assert_nil(@obj0.get_image_narray, "A DObject without pixel data should return nil here.")
    assert_equal(false, @obj1.get_image_narray, "When failing to unpack compressed pixel data, false should be returned (This test needs to be changed if compression is successfully implemented at some stage).")
    assert_instance_of(NArray, @obj2.get_image_narray, "The result from get_image_narray() should be a numerical array of pixel data.")
    assert_equal(65536, @obj2.get_image_narray.length, "The pixel data array for this DICOM object should have 65536 elements (256*256 pixels).")
    assert_equal(1024, @obj2.get_image_narray.min, "Minimum pixel data value should be 1024.")
    assert_equal(1284, @obj2.get_image_narray.max, "Minimum pixel data value should be 1284.")
    assert_equal(1024, @obj2.get_image_narray(:remap => true).min, "Minimum pixel data value should still be 1024, as there is no intercept/slope.")
    assert_equal(1284, @obj2.get_image_narray(:remap => true).max, "Minimum pixel data value should be 1284, as there is no intercept/slope.")
    assert_equal(1137, @obj2.get_image_narray(:level => true).max, "Minimum pixel data value should be 1137 (as a result of default center/width remapping).")
    assert_equal(1053, @obj2.get_image_narray(:level => true).min, "Minimum pixel data value should be 1053 (as a result of default center/width remapping).")
    assert_equal(1137, @obj2.get_image_narray(:level => true).max, "Minimum pixel data value should be 1137 (as a result of default center/width remapping).")
    assert_equal(1050, @obj2.get_image_narray(:level => [1100, 100]).min, "Minimum pixel data value should be 1050 (as a result of the requested center/width remapping).")
    assert_equal(1150, @obj2.get_image_narray(:level => [1100, 100]).max, "Minimum pixel data value should be 1150 (as a result of the requested center/width remapping).")
    assert_equal(1050, @obj2.get_image_narray(:level => [1100, 100]).min, "Minimum pixel data value should be 1050 (as a result of the requested center/width remapping).")
    assert_equal(1150, @obj2.get_image_narray(:level => [1100, 100]).max, "Minimum pixel data value should be 1150 (as a result of the requested center/width remapping).")
  end

end