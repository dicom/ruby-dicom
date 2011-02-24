require File.dirname(__FILE__) + '/../test_helper'

class TC_RubyExtensionsTest < Test::Unit::TestCase

  def setup
    @str = "Custom test string"
  end

  def test_divide
    assert_instance_of(Array, @str.divide(1), "Calling divide with 1 as argument should return the string inside an Array.")
    assert_instance_of(Array, @str.divide(2), "The divide method should return the splitted strings inside an Array.")
    assert_equal(1, @str.divide(1).length)
    assert_equal(2, @str.divide(2).length)
    assert_equal(10, @str.divide(10).length)
    assert_equal(@str, @str.divide(1).join, "A divided string that is rejoined should be equal to the original string.")
    assert_equal(@str, @str.divide(2).join, "A divided string that is rejoined should be equal to the original string.")
    assert_equal(@str, @str.divide(10).join, "A divided string that is rejoined should be equal to the original string.")
  end

  def test_unpack
    assert_instance_of(Array, "00".unpack(CUSTOM_SS), "Unpacking a string with our extension to the method should return an Array, as normal.")
    assert_instance_of(Array, "0000".unpack(CUSTOM_SL), "Unpacking a string with our extension to the method should return an Array, as normal.")
    assert_equal(1, "00".unpack(CUSTOM_SS).length, "Unpacking a 2 byte String as a signed short should result in a 1 element Array.")
    assert_equal(1, "0000".unpack(CUSTOM_SL).length, "Unpacking a 4 byte String as a signed long should result in a 1 element Array.")
    assert_equal("\360\377".unpack("s*"), "\377\360".unpack(CUSTOM_SS), "Unpacking a reversed String as a big endian short should give the same result as unpacking the String as a little endian short.")
    assert_equal("\360\377\377\377".unpack("l*"), "\377\377\377\360".unpack(CUSTOM_SL), "Unpacking a reversed String as a big endian long should give the same result as unpacking the String as a little endian long.")
  end

  def test_pack
    assert_instance_of(String, [-16].pack(CUSTOM_SS), "Packing an integer array with our extension to the method should return a String, as normal.")
    assert_instance_of(String, [-16].pack(CUSTOM_SL), "Packing an integer array with our extension to the method should return a String, as normal.")
    assert_equal(2, [-16].pack(CUSTOM_SS).length, "Packing a signed short should result in a 2 byte String.")
    assert_equal(4, [-16].pack(CUSTOM_SL).length, "Packing a signed long should result in a 4 byte String.")
    assert_equal([-16].pack("s*").reverse, [-16].pack(CUSTOM_SS), "Packing a signed short with little endian byte order, then reversing it, should give the same result as packing it with big endian byte order.")
    assert_equal([-16].pack("l*").reverse, [-16].pack(CUSTOM_SL), "Packing a signed long with little endian byte order, then reversing it, should give the same result as packing it with big endian byte order.")
  end

end