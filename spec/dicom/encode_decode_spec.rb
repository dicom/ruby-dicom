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
  
  
  # Little endian string decoding:
  describe Stream, "#decode" do
    
    it "should raise ArgumentError if the length is not an Integer" do
      stream = Stream.new("test", endian=false)
      expect {stream.decode(false, "US")}.to raise_error(ArgumentError)
      expect {stream.decode("test", "AE")}.to raise_error(ArgumentError)
    end
    
    it "should raise ArgumentError if the VR is not a string" do
      stream = Stream.new("test", endian=false)
      expect {stream.decode(4, false)}.to raise_error(ArgumentError)
      expect {stream.decode(4, 2)}.to raise_error(ArgumentError)
    end

    it "should return the expected string when decoding with the various string type value representations" do
      stream = Stream.new("test"*15, endian=false)
      stream.decode(4, "AE").should eql "test"
      stream.decode(4, "AS").should eql "test"
      stream.decode(4, "CS").should eql "test"
      stream.decode(4, "DA").should eql "test"
      stream.decode(4, "DS").should eql "test"
      stream.decode(4, "DT").should eql "test"
      stream.decode(4, "IS").should eql "test"
      stream.decode(4, "LO").should eql "test"
      stream.decode(4, "LT").should eql "test"
      stream.decode(4, "PN").should eql "test"
      stream.decode(4, "SH").should eql "test"
      stream.decode(4, "ST").should eql "test"
      stream.decode(4, "TM").should eql "test"
      stream.decode(4, "UI").should eql "test"
      stream.decode(4, "UT").should eql "test"
    end
    
    it "should return the expected string when decoding with our custom string type value representation" do
      stream = Stream.new("test", endian=false)
      stream.decode(4, "STR").should eql "test"
    end
    
    it "should properly decode a byte integer from a little endian binary string" do
      stream = Stream.new("\377", endian=false)
      stream.decode(1, "BY").should eql 255
    end
    
    it "should properly decode an unsigned short integer from a little endian binary string" do
      stream = Stream.new("\377\000", endian=false)
      stream.decode(2, "US").should eql 255
    end
    
    it "should properly decode a signed short integer from a little endian binary string" do
      stream = Stream.new("\001\377", endian=false)  
      stream.decode(2, "SS").should eql -255
    end
    
    it "should properly decode an unsigned long integer from a little endian binary string" do
      stream = Stream.new("\320\001\001\000", endian=false)
      stream.decode(4, "UL").should eql 66000
    end
    
    it "should properly decode a signed long integer from a little endian binary string" do
      stream = Stream.new("0\376\376\377", endian=false)
      stream.decode(4, "SL").should eql -66000
    end
    
    it "should properly decode a floating point single from a little endian binary string" do
      stream = Stream.new("\000\000\177C", endian=false)
      stream.decode(4, "FL").should eql 255.0
    end
    
    it "should properly decode a floating point double from a little endian binary string" do
      stream = Stream.new("\315\314\314\314\314@\217@", endian=false)
      stream.decode(8, "FD").should eql 1000.1
    end
    
    it "should properly decode an 'other byte' as a byte integer from a little endian binary string" do
      stream = Stream.new("\377", endian=false)
      stream.decode(1, "OB").should eql 255
    end
    
    it "should properly decode an 'other word' as an unsigned short from a little endian binary string" do
      stream = Stream.new("\377\000", endian=false)
      stream.decode(2, "OW").should eql 255
    end
    
    it "should properly decode an 'other float' as a floating point single from a little endian binary string" do
      stream = Stream.new("\000\000\177C", endian=false)
      stream.decode(4, "OF").should eql 255.0
    end

  end
  
  
  # Big endian string decoding:
  describe Stream, "#decode" do
    
    it "should return the expected string when decoding with our custom string type value representation" do
      stream = Stream.new("test", endian=true)
      stream.decode(4, "STR").should eql "test"
    end
    
    it "should properly decode a byte integer from a big endian binary string" do
      stream = Stream.new("\377", endian=true)
      stream.decode(1, "BY").should eql 255
    end
    
    it "should properly decode an unsigned short integer from a big endian binary string" do
      stream = Stream.new("\000\377", endian=true)
      stream.decode(2, "US").should eql 255
    end
    
    it "should properly decode a signed short integer from a big endian binary string" do
      stream = Stream.new("\377\001", endian=true)  
      stream.decode(2, "SS").should eql -255
    end
    
    it "should properly decode an unsigned long integer from a big endian binary string" do
      stream = Stream.new("\000\001\001\320", endian=true)
      stream.decode(4, "UL").should eql 66000
    end
    
    it "should properly decode a signed long integer from a big endian binary string" do
      stream = Stream.new("\377\376\3760", endian=true)
      stream.decode(4, "SL").should eql -66000
    end
    
    it "should properly decode a floating point single from a big endian binary string" do
      stream = Stream.new("C\177\000\000", endian=true)
      stream.decode(4, "FL").should eql 255.0
    end
    
    it "should properly decode a floating point double from a big endian binary string" do
      stream = Stream.new("@\217@\314\314\314\314\315", endian=true)
      stream.decode(8, "FD").should eql 1000.1
    end
    
    it "should properly decode an 'other byte' as a byte integer from a big endian binary string" do
      stream = Stream.new("\377", endian=true)
      stream.decode(1, "OB").should eql 255
    end
    
    it "should properly decode an 'other word' as an unsigned short from a big endian binary string" do
      stream = Stream.new("\000\377", endian=true)
      stream.decode(2, "OW").should eql 255
    end
    
    it "should properly decode an 'other float' as a floating point single from a big endian binary string" do
      stream = Stream.new("C\177\000\000", endian=true)
      stream.decode(4, "OF").should eql 255.0
    end

  end
  
end