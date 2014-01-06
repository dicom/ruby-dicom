# encoding: UTF-8

require 'spec_helper'


module DICOM

  describe String, "#tag?" do

    it "should return true for any string that follows the ruby-dicom tag definition of 'GGGG,EEEE', where G and E are hexadecimals" do
      expect("0000,0000".tag?).to eql true
      expect("ABCD,EF12".tag?).to eql true
      expect("3456,7899".tag?).to eql true
      expect("FFFF,FFFF".tag?).to eql true
      expect("ffff,ffff".tag?).to eql true
    end

    it "should return false for any string that deviates from the ruby-dicom tag definition of 'GGGG,EEEE', where G and E are hexadecimals" do
      expect("0000".tag?).to be_false
      expect("0010,00000".tag?).to be_false
      expect("F00E,".tag?).to be_false
      expect(",0000".tag?).to be_false
      expect("000G,0000".tag?).to be_false
      expect("0000,000H".tag?).to be_false
      expect("AAA,ACCCC".tag?).to be_false
      expect(",AAAACCCC".tag?).to be_false
      expect("AAAACCCC,".tag?).to be_false
      expect("tyui;pqwx,".tag?).to be_false
      expect("-000,0000".tag?).to be_false
      expect("-0000,0000".tag?).to be_false
      expect("0000.0000".tag?).to be_false
      expect("00000000".tag?).to be_false
    end

  end

  describe String, "#private?" do

    it "should return true for any string that per definition is a private tag (it's group ends with an odd hexadecimal)" do
      expect("0001,0000".private?).to eql true
      expect("0003,0000".private?).to eql true
      expect("0005,0000".private?).to eql true
      expect("0007,0000".private?).to eql true
      expect("0009,0000".private?).to eql true
      expect("000B,0000".private?).to eql true
      expect("000D,0000".private?).to eql true
      expect("000F,0000".private?).to eql true
    end

    it "should return false for any string that is not a private tag" do
      expect("0000,0000".private?).to be_false
      expect("1110,1111".private?).to be_false
      expect("0002,0003".private?).to be_false
      expect("0004,0055".private?).to be_false
      expect("0006,0707".private?).to be_false
      expect("0008,9009".private?).to be_false
      expect("00BA,000B".private?).to be_false
      expect("0D0C,000D".private?).to be_false
      expect("F00E,000F".private?).to be_false
    end

  end

  describe String, "#group" do

    it "should return the group part of the tag string" do
      expect("0002,0010".group).to eql "0002"
    end

  end

  describe String, "#element" do

    it "should return the element part of the tag string" do
      expect("0002,0010".element).to eql "0010"
    end

  end

  describe String, "#group_length?" do

    it "should return the group length tag which corresponds to the group the given tag belongs to" do
      expect("0010,0020".group_length).to eql "0010,0000"
    end

    it "should return the full group length tag which corresponds to the given tag group" do
      expect("0010".group_length).to eql "0010,0000"
    end

  end

  describe String, "#group_length?" do

    it "should return true for any valid group length tag string" do
      expect("0000,0000".group_length?).to eql true
      expect("2222,0000".group_length?).to eql true
    end

    it "should return false when the string is not a valid group length tag" do
      expect("0010,0020".group_length?).to be_false
      expect("0010".group_length?).to be_false
    end

  end

  describe String, "#divide" do

    it "should raise ArgumentError if argument is not a Fixnum" do
      expect {"test".divide("error")}.to raise_error(ArgumentError)
    end

    it "should raise ArgumentError if argument is less than 1" do
      expect {"test".divide(0)}.to raise_error(ArgumentError)
    end

    it "should raise ArgumentError if argument is bigger than the length of the string" do
      expect {"test".divide(5)}.to raise_error(ArgumentError)
    end

    it "should raise ArgumentError if an argument is used that results in the string not being a multiple of the argument" do
      expect {"Custom test string".divide(10)}.to raise_error(ArgumentError)
    end

    it "should return an array when the method is called with unity, i.e. it doesn't split the string" do
      expect("test".divide(1).class).to eql Array
    end

    it "should return an array when the method is called with an argument that splits the string in several pieces" do
      expect("test".divide(2).class).to eql Array
    end

    it "should return an array with length equal to that specified in the argument" do
      expect("Custom test string".divide(1).length).to eql 1
      expect("Custom test string".divide(2).length).to eql 2
      expect("Custom test string".divide(9).length).to eql 9
    end

    it "should return an array of sub-strings which when joined together is equal to the original string" do
      expect("Custom test string".divide(1).join).to eql "Custom test string"
      expect("Custom test string".divide(2).join).to eql "Custom test string"
      expect("Custom test string".divide(9).join).to eql "Custom test string"
    end

  end

end