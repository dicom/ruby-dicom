# coding: UTF-8

require 'spec_helper'


module DICOM

  describe DICOM do
    
    context "When handling Data Elements with tag values (VR = 'AT')," do
    
    
      context DObject, "#value" do
        
        it "should return the proper tag string" do
          obj = DObject.new(Dir.pwd+'/spec/support/sample_no-header_implicit_mr_16bit_mono2.dcm', :verbose => false)
          obj.value("0020,5000").should eql "0010,0010"
        end
      
      end


      context DObject, "#value=()" do
        
        it "should encode the value as a proper binary tag, for a little endian DICOM object" do
          obj = DObject.new(Dir.pwd+'/spec/support/sample_no-header_implicit_mr_16bit_mono2.dcm', :verbose => false)
          obj["0020,5000"].value = "10B0,C0A0"
          obj["0020,5000"].bin.should eql "\260\020\240\300"
        end
      
      end


      context DataElement, "#new" do
      
        it "should properly encode its value as a binary tag in, using default (little endian) encoding" do
          element = DataElement.new("0020,5000", "10B0,C0A0")
          element.bin.should eql "\260\020\240\300"
        end
        
      end


      context DObject, "#add" do
      
        it "should add the Data Element with its value properly encoded as a binary tag, for an empty (little endian) DICOM object" do
          obj = DObject.new(nil, :verbose => false)
          obj.add(DataElement.new("0020,5000", "10B0,C0A0"))
          obj["0020,5000"].bin.should eql "\260\020\240\300"
        end
        
        it "should add the Data Element with its value properly encoded as a binary tag, for an empty (big endian) DICOM object" do
          obj = DObject.new(nil, :verbose => false)
          obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
          obj.add(DataElement.new("0020,5000", "10B0,C0A0"))
          obj["0020,5000"].bin.should eql "\020\260\300\240"
        end
        
      end


      context DObject, "#transfer_syntax=()" do
      
        it "should properly re-encode the Data Element value, when the endianness of the DICOM object is changed" do
          obj = DObject.new(nil, :verbose => false)
          obj.add(DataElement.new("0020,5000", "10B0,C0A0"))
          obj.transfer_syntax = EXPLICIT_BIG_ENDIAN
          obj["0020,5000"].bin.should eql "\020\260\300\240"
        end
      
      end
    
    end
  
  end

end