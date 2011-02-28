# coding: UTF-8

require 'spec_helper'

# Note: The float encoding/decoding specs have not been truly verified to be correct.
module DICOM

  # Little endian string encoding:
  describe Stream, "#encode" do
    
      before :each do
        @stream = Stream.new(nil, endian=false)
      end
      
      it "should raise ArgumentError if the VR is not a string" do
        expect {@stream.encode("test", false)}.to raise_error(ArgumentError)
        expect {@stream.encode("test", 2)}.to raise_error(ArgumentError)
      end
      
      it "should encode values using the various string type value representations as string" do
        @stream.encode("test", "AE").should eql "test"
        @stream.encode("test", "AS").should eql "test"
        @stream.encode("test", "CS").should eql "test"
        @stream.encode("test", "DA").should eql "test"
        @stream.encode("test", "DS").should eql "test"
        @stream.encode("test", "DT").should eql "test"
        @stream.encode("test", "IS").should eql "test"
        @stream.encode("test", "LO").should eql "test"
        @stream.encode("test", "LT").should eql "test"
        @stream.encode("test", "PN").should eql "test"
        @stream.encode("test", "SH").should eql "test"
        @stream.encode("test", "ST").should eql "test"
        @stream.encode("test", "TM").should eql "test"
        @stream.encode("test", "UI").should eql "test"
        @stream.encode("test", "UT").should eql "test"
      end
      
      it "should encode values using our custom string type value representation as string" do
        @stream.encode("test", "STR").should eql "test"
      end
      
      it "should properly encode a byte integer to a little endian binary string" do
        @stream.encode(255, "BY").should eql "\377"
      end
      
      it "should properly encode an unsigned short integer to a little endian binary string" do
        @stream.encode(255, "US").should eql "\377\000"
      end
      
      it "should properly encode a signed short integer to a little endian binary string" do
        @stream.encode(-255, "SS").should eql "\001\377"
      end
      
      it "should properly encode an unsigned long integer to a little endian binary string" do
        @stream.encode(66000, "UL").should eql "\320\001\001\000"
      end
      
      it "should properly encode a signed long integer to a little endian binary string" do
        @stream.encode(-66000, "SL").should eql "0\376\376\377"
      end
      
      it "should properly encode a floating point single to a little endian binary string" do
        @stream.encode(255.0, "FL").should eql "\000\000\177C"
      end
      
      it "should properly encode a floating point double to a little endian binary string" do
        @stream.encode(1000.1, "FD").should eql "\315\314\314\314\314@\217@"
      end
      
      it "should properly encode an 'other byte' as a byte integer to a little endian binary string" do
        @stream.encode(255, "OB").should eql "\377"
      end
      
      it "should properly encode an 'other word' as an unsigned short to a little endian binary string" do
        @stream.encode(255, "OW").should eql "\377\000"
      end
      
      it "should properly encode an 'other float' as a floating point single to a little endian binary string" do
        @stream.encode(255.0, "OF").should eql "\000\000\177C"
      end
    
  end
  
  # Big endian string encoding:
  describe Stream, "#encode" do
    
    before :each do
      @stream = Stream.new(nil, endian=true)
    end
    
    it "should encode values using our custom string type value representation as string" do
      @stream.encode("test", "STR").should eql "test"
    end
    
    it "should properly encode a byte integer to a big endian binary string" do
      @stream.encode(255, "BY").should eql "\377"
    end
    
    it "should properly encode an unsigned short integer to a big endian binary string" do
      @stream.encode(255, "US").should eql "\000\377"
    end
    
    it "should properly encode a signed short integer to a big endian binary string" do
      @stream.encode(-255, "SS").should eql "\377\001"
    end
    
    it "should properly encode an unsigned long integer to a big endian binary string" do
      @stream.encode(66000, "UL").should eql "\000\001\001\320"
    end
    
    it "should properly encode a signed long integer to a big endian binary string" do
      @stream.encode(-66000, "SL").should eql "\377\376\3760"
    end
    
    it "should properly encode a floating point single to a big endian binary string" do
      @stream.encode(255.0, "FL").should eql "C\177\000\000"
    end
    
    it "should properly encode a floating point double to a big endian binary string" do
      @stream.encode(1000.1, "FD").should eql "@\217@\314\314\314\314\315"
    end
    
    it "should properly encode an 'other byte' as a byte integer to a big endian binary string" do
      @stream.encode(255, "OB").should eql "\377"
    end
    
    it "should properly encode an 'other word' as an unsigned short to a big endian binary string" do
      @stream.encode(255, "OW").should eql "\000\377"
    end
    
    it "should properly encode an 'other float' as a floating point single to a big endian binary string" do
      @stream.encode(255.0, "OF").should eql "C\177\000\000"
    end
    
  end
  
  # Little endian string encoding:
  #describe Stream, "#decode" do
  #end
  
end