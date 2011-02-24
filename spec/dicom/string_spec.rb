# coding: UTF-8

require 'spec_helper'


module DICOM

  describe String, "#tag?" do
    
    it "should return true for any string that follows the ruby-dicom tag definition of 'GGGG,EEEE', where G and E are hexadecimals" do
      "0000,0000".tag?.should eql true
      "ABCD,EF12".tag?.should eql true
      "3456,7899".tag?.should eql true
      "FFFF,FFFF".tag?.should eql true
      "ffff,ffff".tag?.should eql true
    end
    
    it "should return false for any string that deviates from the ruby-dicom tag definition of 'GGGG,EEEE', where G and E are hexadecimals" do
      "0000".tag?.should be_false
      "0010,00000".tag?.should be_false
      "F00E,".tag?.should be_false
      ",0000".tag?.should be_false
      "000G,0000".tag?.should be_false
      "0000,000H".tag?.should be_false
      "AAA,ACCCC".tag?.should be_false
      ",AAAACCCC".tag?.should be_false
      "AAAACCCC,".tag?.should be_false
      "tyui;pqwx,".tag?.should be_false
      "-000,0000".tag?.should be_false
      "-0000,0000".tag?.should be_false
      "0000.0000".tag?.should be_false
      "00000000".tag?.should be_false
    end
    
  end
  
  describe String, "#private?" do
    
    it "should return true for any string that per definition is a private tag (it's group ends with an odd hexadecimal)" do
      "0001,0000".private?.should eql true
      "0003,0000".private?.should eql true
      "0005,0000".private?.should eql true
      "0007,0000".private?.should eql true
      "0009,0000".private?.should eql true
      "000B,0000".private?.should eql true
      "000D,0000".private?.should eql true
      "000F,0000".private?.should eql true
    end
    
    it "should return false for any string that is not a private tag" do
      "0000,0000".private?.should be_false
      "1110,1111".private?.should be_false
      "0002,0003".private?.should be_false
      "0004,0055".private?.should be_false
      "0006,0707".private?.should be_false
      "0008,9009".private?.should be_false
      "00BA,000B".private?.should be_false
      "0D0C,000D".private?.should be_false
      "F00E,000F".private?.should be_false
    end
    
  end
  
  describe String, "#group" do
    
    it "should return the group part of the tag string" do
      "0002,0010".group.should eql "0002"
    end
    
  end
  
  describe String, "#element" do
    
    it "should return the element part of the tag string" do
      "0002,0010".element.should eql "0010"
    end
    
  end
  
  describe String, "#group_length?" do
    
    it "should return the group length tag which corresponds to the group the given tag belongs to" do
      "0010,0020".group_length.should eql "0010,0000"
    end
    
    it "should return the full group length tag which corresponds to the given tag group" do
      "0010".group_length.should eql "0010,0000"
    end
    
  end
  
  describe String, "#group_length?" do
    
    it "should return true for any valid group length tag string" do
      "0000,0000".group_length?.should eql true
      "2222,0000".group_length?.should eql true
    end
    
    it "should return false when the string is not a valid group length tag" do
      "0010,0020".group_length?.should be_false
      "0010".group_length?.should be_false
    end
    
  end

end