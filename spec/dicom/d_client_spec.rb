require 'spec_helper'

describe DICOM::DClient, '#find_studies' do
  before :each do
    @link = mock("link")
    @link.stubs(:build_command_fragment)
    @link.stubs(:transmit)
    @link.stubs(:receive_multiple_transmissions)
    DICOM::Link.stubs(:new).returns(@link)
    
    @node = DICOM::DClient.new("127.0.0.1", 11112)
    @node.stubs(:establish_association)
    @node.stubs(:association_established?).returns(true)
    @node.stubs(:request_approved?).returns(true)
    @node.stubs(:presentation_context_id)
    @node.stubs(:process_returned_data)
    @node.stubs(:establish_release)
  end
  
   
  it "should set default query parameters if no options given" do
    data_elements = [["0008,0020", ""],
      ["0008,0030", ""],
      ["0008,0050", ""],
      ["0008,0052", "STUDY"],
      ["0010,0010", ""],
      ["0010,0020", ""],
      ["0020,0010", ""]]
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_studies()
  end
  
  it "should set query parameters from options if given" do
    data_elements = [["0008,0020", "20061231-20070201"],
      ["0008,0030", "015500-235559"],
      ["0008,0050", "Abc789"],
      ["0008,0052", "STUDY"],
      ["0010,0010", "Lumberg^Bill"],
      ["0010,0020", "12345"],
      ["0020,0010", "1.234.567"]]
    options = {"0008,0020"=>"20061231-20070201",  
       "0008,0030"=>"015500-235559",
       "0008,0050"=>"Abc789",
       "0008,0052"=>"STUDY",
       "0010,0010"=>"Lumberg^Bill",
       "0010,0020"=>"12345",
       "0020,0010"=>"1.234.567"}
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_studies(options)
  end
  
  it "should set optional query parameters if given" do
    data_elements = [
      ["0008,0020", ""],
      ["0008,0030", ""],
      ["0008,0050", ""],
      ["0008,0052", "STUDY"],
      ["0008,0061", "CT"],
      ["0008,0090", "Dr. House"],
      ["0008,1030", "knee"],
      ["0008,1060", "Dr. Roentgen"],
      ["0010,0010", ""],
      ["0010,0020", ""],
      ["0010,0030", "19560101-19860101"],
      ["0010,0040", "M"],
      ["0020,000D", "1.23.456.7890"],
      ["0020,0010", ""]]
    options = {"0008,0061"=>"CT",  
       "0008,0090"=>"Dr. House",
       "0008,1030"=>"knee",
       "0008,1060"=>"Dr. Roentgen",
       "0010,0030"=>"19560101-19860101",
       "0010,0040"=>"M",
       "0020,000D"=>"1.23.456.7890"}
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_studies(options)
  end
      
  it "should raise error if unknown query parameter given" do
    @link.stubs(:build_data_fragment)
    lambda {
      @node.find_studies( {"dead,beaf" => "this query parameter is unknown"} )
    }.should raise_error(ArgumentError, /dead,beaf/)
  end
  
end
