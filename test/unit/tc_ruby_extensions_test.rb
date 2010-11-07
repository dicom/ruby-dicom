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

  def test_element
    assert_equal("0010", "0002,0010".element)
  end

  def test_group
    assert_equal("0002", "0002,0010".group)
  end

  def test_group_length
    assert_equal("0010,0000", "0010,0020".group_length)
    assert_equal("0010,0000", "0010".group_length)
  end

  def test_group_length?
    assert("0000,0000".group_length?)
    assert("2222,0000".group_length?)
    assert_equal(false, "0010,0020".group_length?)
    assert_equal(false, "0010".group_length?)
  end

  def test_private?
    assert("0001,0000".private?)
    assert("0003,0000".private?)
    assert("0005,0000".private?)
    assert("0007,0000".private?)
    assert("0009,0000".private?)
    assert("000B,0000".private?)
    assert("000D,0000".private?)
    assert("000F,0000".private?)
    assert_equal(false, "0000,0000".private?)
    assert_equal(false, "1110,1111".private?)
    assert_equal(false, "0002,0003".private?)
    assert_equal(false, "0004,0055".private?)
    assert_equal(false, "0006,0707".private?)
    assert_equal(false, "0008,9009".private?)
    assert_equal(false, "00BA,000B".private?)
    assert_equal(false, "0D0C,000D".private?)
    assert_equal(false, "F00E,000F".private?)
  end

  def test_tag?
    assert("0000,0000".tag?)
    assert("AAEE,0010".tag?)
    assert("FFFF,FFFF".tag?)
    assert_equal(false, "0000".tag?)
    assert_equal(false, "0010,00000".tag?)
    assert_equal(false, "F00E,".tag?)
    assert_equal(false, ",0000".tag?)
    assert_equal(false, "000G,0000".tag?)
    assert_equal(false, "0000,000H".tag?)
    assert_equal(false, "0000.0000".tag?)
    assert_equal(false, "00000000".tag?)
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