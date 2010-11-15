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
  
  it "should set the following default query parameters" do
    data_elements = [["0008,0020", ""],
      ["0008,0030", ""],
      ["0008,0050", ""],
      ["0008,0052", "STUDY"],
      ["0008,0061", ""],
      ["0008,0090", ""],
      ["0008,1030", ""],
      ["0008,1060", ""],
      ["0010,0010", ""],
      ["0010,0020", ""],
      ["0010,0030", ""],
      ["0010,0040", ""],
      ["0020,000D", ""],
      ["0020,0010", ""]]
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_studies()
  end
end