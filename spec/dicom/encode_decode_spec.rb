# encoding: ASCII-8BIT

require 'spec_helper'

# Note: The float encoding/decoding specs have not been truly verified to be correct.
module DICOM

  describe Stream do

    describe "#encode" do

      context "with little endian encoding" do

        before :example do
          @stream = Stream.new(nil, endian=false)
        end

        it "should raise ArgumentError if the VR is not a string" do
          expect {@stream.encode("test", false)}.to raise_error(ArgumentError)
          expect {@stream.encode("test", 2)}.to raise_error(ArgumentError)
        end

        it "should encode values using the various string type value representations as string" do
          expect(@stream.encode("test", "AE")).to eql "test"
          expect(@stream.encode("test", "AS")).to eql "test"
          expect(@stream.encode("test", "CS")).to eql "test"
          expect(@stream.encode("test", "DA")).to eql "test"
          expect(@stream.encode("test", "DS")).to eql "test"
          expect(@stream.encode("test", "DT")).to eql "test"
          expect(@stream.encode("test", "IS")).to eql "test"
          expect(@stream.encode("test", "LO")).to eql "test"
          expect(@stream.encode("test", "LT")).to eql "test"
          expect(@stream.encode("test", "PN")).to eql "test"
          expect(@stream.encode("test", "SH")).to eql "test"
          expect(@stream.encode("test", "ST")).to eql "test"
          expect(@stream.encode("test", "TM")).to eql "test"
          expect(@stream.encode("test", "UI")).to eql "test"
          expect(@stream.encode("test", "UT")).to eql "test"
        end

        it "should encode values using our custom string type value representation as string" do
          expect(@stream.encode("test", "STR")).to eql "test"
        end

        it "should properly encode a byte integer to a little endian binary string" do
          expect(@stream.encode(255, "BY")).to eql "\377"
        end

        it "should properly encode an unsigned short integer to a little endian binary string" do
          expect(@stream.encode(255, "US")).to eql "\377\000"
        end

        it "should properly encode a signed short integer to a little endian binary string" do
          expect(@stream.encode(-255, "SS")).to eql "\001\377"
        end

        it "should properly encode an unsigned long integer to a little endian binary string" do
          expect(@stream.encode(66000, "UL")).to eql "\320\001\001\000"
        end

        it "should properly encode a signed long integer to a little endian binary string" do
          expect(@stream.encode(-66000, "SL")).to eql "0\376\376\377"
        end

        it "should properly encode a floating point single to a little endian binary string" do
          expect(@stream.encode(255.0, "FL")).to eql "\000\000\177C"
        end

        it "should properly encode a floating point double to a little endian binary string" do
          expect(@stream.encode(1000.1, "FD")).to eql "\315\314\314\314\314@\217@"
        end

        it "should properly encode an 'other byte' as a byte integer to a little endian binary string" do
          expect(@stream.encode(255, "OB")).to eql "\377"
        end

        it "should properly encode an 'other word' as an unsigned short to a little endian binary string" do
          expect(@stream.encode(255, "OW")).to eql "\377\000"
        end

        it "should properly encode an 'other float' as a floating point single to a little endian binary string" do
          expect(@stream.encode(255.0, "OF")).to eql "\000\000\177C"
        end

      end

      context "with big endian encoding" do

        before :example do
          @stream = Stream.new(nil, endian=true)
        end

        it "should encode values using our custom string type value representation as string" do
          expect(@stream.encode("test", "STR")).to eql "test"
        end

        it "should properly encode a byte integer to a big endian binary string" do
          expect(@stream.encode(255, "BY")).to eql "\377"
        end

        it "should properly encode an unsigned short integer to a big endian binary string" do
          expect(@stream.encode(255, "US")).to eql "\000\377"
        end

        it "should properly encode a signed short integer to a big endian binary string" do
          expect(@stream.encode(-255, "SS")).to eql "\377\001"
        end

        it "should properly encode an unsigned long integer to a big endian binary string" do
          expect(@stream.encode(66000, "UL")).to eql "\000\001\001\320"
        end

        it "should properly encode a signed long integer to a big endian binary string" do
          expect(@stream.encode(-66000, "SL")).to eql "\377\376\3760"
        end

        it "should properly encode a floating point single to a big endian binary string" do
          expect(@stream.encode(255.0, "FL")).to eql "C\177\000\000"
        end

        it "should properly encode a floating point double to a big endian binary string" do
          expect(@stream.encode(1000.1, "FD")).to eql "@\217@\314\314\314\314\315"
        end

        it "should properly encode an 'other byte' as a byte integer to a big endian binary string" do
          expect(@stream.encode(255, "OB")).to eql "\377"
        end

        it "should properly encode an 'other word' as an unsigned short to a big endian binary string" do
          expect(@stream.encode(255, "OW")).to eql "\000\377"
        end

        it "should properly encode an 'other float' as a floating point single to a big endian binary string" do
          expect(@stream.encode(255.0, "OF")).to eql "C\177\000\000"
        end

      end

    end


    describe "#decode" do

      context "with little endian decoding" do

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
          expect(stream.decode(4, "AE")).to eql "test"
          expect(stream.decode(4, "AS")).to eql "test"
          expect(stream.decode(4, "CS")).to eql "test"
          expect(stream.decode(4, "DA")).to eql "test"
          expect(stream.decode(4, "DS")).to eql "test"
          expect(stream.decode(4, "DT")).to eql "test"
          expect(stream.decode(4, "IS")).to eql "test"
          expect(stream.decode(4, "LO")).to eql "test"
          expect(stream.decode(4, "LT")).to eql "test"
          expect(stream.decode(4, "PN")).to eql "test"
          expect(stream.decode(4, "SH")).to eql "test"
          expect(stream.decode(4, "ST")).to eql "test"
          expect(stream.decode(4, "TM")).to eql "test"
          expect(stream.decode(4, "UI")).to eql "test"
          expect(stream.decode(4, "UT")).to eql "test"
        end

        it "should return the expected string when decoding with our custom string type value representation" do
          stream = Stream.new("test", endian=false)
          expect(stream.decode(4, "STR")).to eql "test"
        end

        it "should properly decode a byte integer from a little endian binary string" do
          stream = Stream.new("\377", endian=false)
          expect(stream.decode(1, "BY")).to eql 255
        end

        it "should properly decode an unsigned short integer from a little endian binary string" do
          stream = Stream.new("\377\000", endian=false)
          expect(stream.decode(2, "US")).to eql 255
        end

        it "should properly decode a signed short integer from a little endian binary string" do
          stream = Stream.new("\001\377", endian=false)
          expect(stream.decode(2, "SS")).to eql -255
        end

        it "should properly decode an unsigned long integer from a little endian binary string" do
          stream = Stream.new("\320\001\001\000", endian=false)
          expect(stream.decode(4, "UL")).to eql 66000
        end

        it "should properly decode a signed long integer from a little endian binary string" do
          stream = Stream.new("0\376\376\377", endian=false)
          expect(stream.decode(4, "SL")).to eql -66000
        end

        it "should properly decode a floating point single from a little endian binary string" do
          stream = Stream.new("\000\000\177C", endian=false)
          expect(stream.decode(4, "FL")).to eql 255.0
        end

        it "should properly decode a floating point double from a little endian binary string" do
          stream = Stream.new("\315\314\314\314\314@\217@", endian=false)
          expect(stream.decode(8, "FD")).to eql 1000.1
        end

        it "should properly decode an 'other byte' as a byte integer from a little endian binary string" do
          stream = Stream.new("\377", endian=false)
          expect(stream.decode(1, "OB")).to eql 255
        end

        it "should properly decode an 'other word' as an unsigned short from a little endian binary string" do
          stream = Stream.new("\377\000", endian=false)
          expect(stream.decode(2, "OW")).to eql 255
        end

        it "should properly decode an 'other float' as a floating point single from a little endian binary string" do
          stream = Stream.new("\000\000\177C", endian=false)
          expect(stream.decode(4, "OF")).to eql 255.0
        end

      end

      context "with big endian encoding" do

        it "should return the expected string when decoding with our custom string type value representation" do
          stream = Stream.new("test", endian=true)
          expect(stream.decode(4, "STR")).to eql "test"
        end

        it "should properly decode a byte integer from a big endian binary string" do
          stream = Stream.new("\377", endian=true)
          expect(stream.decode(1, "BY")).to eql 255
        end

        it "should properly decode an unsigned short integer from a big endian binary string" do
          stream = Stream.new("\000\377", endian=true)
          expect(stream.decode(2, "US")).to eql 255
        end

        it "should properly decode a signed short integer from a big endian binary string" do
          stream = Stream.new("\377\001", endian=true)
          expect(stream.decode(2, "SS")).to eql -255
        end

        it "should properly decode an unsigned long integer from a big endian binary string" do
          stream = Stream.new("\000\001\001\320", endian=true)
          expect(stream.decode(4, "UL")).to eql 66000
        end

        it "should properly decode a signed long integer from a big endian binary string" do
          stream = Stream.new("\377\376\3760", endian=true)
          expect(stream.decode(4, "SL")).to eql -66000
        end

        it "should properly decode a floating point single from a big endian binary string" do
          stream = Stream.new("C\177\000\000", endian=true)
          expect(stream.decode(4, "FL")).to eql 255.0
        end

        it "should properly decode a floating point double from a big endian binary string" do
          stream = Stream.new("@\217@\314\314\314\314\315", endian=true)
          expect(stream.decode(8, "FD")).to eql 1000.1
        end

        it "should properly decode an 'other byte' as a byte integer from a big endian binary string" do
          stream = Stream.new("\377", endian=true)
          expect(stream.decode(1, "OB")).to eql 255
        end

        it "should properly decode an 'other word' as an unsigned short from a big endian binary string" do
          stream = Stream.new("\000\377", endian=true)
          expect(stream.decode(2, "OW")).to eql 255
        end

        it "should properly decode an 'other float' as a floating point single from a big endian binary string" do
          stream = Stream.new("C\177\000\000", endian=true)
          expect(stream.decode(4, "OF")).to eql 255.0
        end

      end

    end

  end

end