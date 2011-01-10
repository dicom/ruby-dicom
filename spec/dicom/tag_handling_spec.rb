# coding: UTF-8

require 'spec_helper'


module DICOM

  describe DICOM do
    
     context "Tag handling" do
       
      context DObject do
        
        it "should return the value of a data element with value representation 'AT' as a proper tag string" do
          obj = DObject.new(Dir.pwd+'/spec/support/sample_no-header_implicit_mr_16bit_mono2.dcm', :verbose => false)
          obj.value("0020,5000").should eql "0010,0010"
        end
        
        it "should encode the value of a data element with value representation 'AT' as a proper binary tag in a little endian DICOM object" do
          obj = DObject.new(Dir.pwd+'/spec/support/sample_no-header_implicit_mr_16bit_mono2.dcm', :verbose => false)
          obj["0020,5000"].value = "10B0,C0A0"
          obj["0020,5000"].bin.should eql "\260\020\240\300"
        end
        
        it "should encode the value of a data element with value representation 'AT' as a proper binary tag in a big endian DICOM object" do
          obj = DObject.new(nil, :verbose => false)
          obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
          obj.add(DataElement.new("0020,5000", "10B0,C0A0"))
          obj["0020,5000"].bin.should eql "\020\260\300\240"
        end
        
        it "should re-encode the value of a data element with value representation 'AT' when changing the endianness of the DICOM object" do
          obj = DObject.new(nil, :verbose => false)
          obj.add(DataElement.new("0020,5000", "10B0,C0A0"))
          obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
          obj["0020,5000"].bin.should eql "\020\260\300\240"
        end
        
        it "should encode the value of a data element with value representation 'AT' as a proper binary tag in an empty (little endian) DICOM object" do
          obj = DObject.new(nil, :verbose => false)
          obj.add(DataElement.new("0020,5000", "10B0,C0A0"))
          obj["0020,5000"].bin.should eql "\260\020\240\300"
        end
        
      end
      
    end
    
  end
  
end