require 'spec_helper'


describe DICOM::DClient, '#find_images' do

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

  it "should set required query parameters if not given" do
    data_elements = [["0008,0018", ""],
      ["0008,0052", "IMAGE"],
      ["0020,0013", ""]
    ]
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_images()
  end
  
  it "should set required query parameters if given" do
    data_elements = [["0008,0018", "1.554.762"],
      ["0008,0052", "IMAGE"],
      ["0020,0013", "989"]
    ]
    options = {"0008,0018" => "1.554.762",
        "0008,0052" => "IMAGE",
        "0020,0013" => "989"
      }
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_images(options)
  end
  
  it "should set optional query parameters if given" do
    data_elements = [["0008,0016", "1.245.765"],
      ["0008,0018", "1.554.762"],
      ["0008,001A", "1.933.221"],
      ["0008,0052", "IMAGE"],
      ["0020,000D", "1.554.991"],
      ["0020,000E", "1.556.992"],
      ["0020,0013", "989"],
      ["0040,0512", "MM"]
    ]
    options = Hash.new
    data_elements.collect {|element| options[element.first] = element.last}
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_images(options)
  end
      
  it "should raise error if unknown query parameter given" do
    @link.stubs(:build_data_fragment)
    lambda {
      @node.find_images( {"dead,beaf" => "this query parameter is unknown"} )
    }.should raise_error(ArgumentError, /dead,beaf/)
  end

  it "should reset parameters from previous queries" do
    data_elements = [["0008,0018", ""],
      ["0008,0052", "IMAGE"],
      ["0020,0013", ""]
    ]
    @link.expects(:build_data_fragment).twice.with(data_elements, nil)
    @node.find_images()
    @node.find_images()
  end

end


describe DICOM::DClient, '#find_patients' do

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

  it "should set required query parameters if not given" do
    data_elements = [["0008,0052", "PATIENT"],
      ["0010,0010", ""],
      ["0010,0020", ""]
    ]
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_patients()
  end
  
  it "should set required query parameters if given" do
    data_elements = [["0008,0052", "PATIENT"],
      ["0010,0010", "Lumberg^Bill"],
      ["0010,0020", "12345"]
    ]
    options = {"0008,0052"=>"PATIENT",
      "0010,0010"=>"Lumberg^Bill",
      "0010,0020"=>"12345",
    }
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_patients(options)
  end
  
  it "should set optional query parameters if given" do
    data_elements = [["0008,0052", "PATIENT"],
      ["0010,0010", ""],
      ["0010,0020", ""],
      ["0010,0030", "19560101-19860101"],
      ["0010,0032", "190000-200000"],
      ["0010,0040", "M"],
      ["0010,1000", "Wig"],
      ["0010,1001", "Big"],
      ["0010,2160", "Eskimo"],
      ["0010,4000", "Want to go home"],
      ["0020,1200", "2"],
      ["0020,1202", "5"],
      ["0020,1204", "225"]
    ]
    options = Hash.new
    data_elements.collect {|element| options[element.first] = element.last}
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_patients(options)
  end
      
  it "should raise error if unknown query parameter given" do
    @link.stubs(:build_data_fragment)
    lambda {
      @node.find_patients( {"dead,beaf" => "this query parameter is unknown"} )
    }.should raise_error(ArgumentError, /dead,beaf/)
  end

  it "should reset parameters from previous queries" do
    data_elements = [["0008,0052", "PATIENT"],
      ["0010,0010", ""],
      ["0010,0020", ""]
    ]
    @link.expects(:build_data_fragment).twice.with(data_elements, nil)
    @node.find_patients()
    @node.find_patients()
  end
  
end


describe DICOM::DClient, '#find_series' do

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

  it "should set required query parameters if not given" do
    data_elements = [["0008,0052", "SERIES"],
      ["0008,0060", ""],
      ["0020,000E", ""],
      ["0020,0011", ""]
    ]
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_series()
  end
  
  it "should set required query parameters if given" do
    data_elements = [["0008,0052", "SERIES"],
      ["0008,0060", "MR"],
      ["0020,000E", "1.245.1233"],
      ["0020,0011", "454"]
    ]
    options = {"0008,0052"=>"SERIES",  
      "0008,0060"=>"MR",
      "0020,000E"=>"1.245.1233",
      "0020,0011"=>"454"
    }
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_series(options)
  end
  
  it "should set optional query parameters if given" do
    data_elements = [["0008,0052", "SERIES"],
      ["0008,0060", "MR"],
      ["0008,103E", "T1"],
      ["0020,000D", "1.122.5433"],
      ["0020,000E", "1.245.1233"],
      ["0020,0011", "454"],
      ["0020,1209", "45"]
    ]
    options = Hash.new
    data_elements.collect {|element| options[element.first] = element.last}
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_series(options)
  end
      
  it "should raise error if unknown query parameter given" do
    @link.stubs(:build_data_fragment)
    lambda {
      @node.find_series( {"dead,beaf" => "this query parameter is unknown"} )
    }.should raise_error(ArgumentError, /dead,beaf/)
  end

  it "should reset parameters from previous queries" do
    data_elements = [["0008,0052", "SERIES"],
      ["0008,0060", ""],
      ["0020,000E", ""],
      ["0020,0011", ""]
    ]
    @link.expects(:build_data_fragment).twice.with(data_elements, nil)
    @node.find_series()
    @node.find_series()
  end

end


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

  it "should set required query parameters if not given" do
    data_elements = [["0008,0020", ""],
      ["0008,0030", ""],
      ["0008,0050", ""],
      ["0008,0052", "STUDY"],
      ["0010,0010", ""],
      ["0010,0020", ""],
      ["0020,000D", ""],
      ["0020,0010", ""]
    ]
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_studies()
  end
  
  it "should set required query parameters if given" do
    data_elements = [["0008,0020", "20061231-20070201"],
      ["0008,0030", "015500-235559"],
      ["0008,0050", "Abc789"],
      ["0008,0052", "STUDY"],
      ["0010,0010", "Lumberg^Bill"],
      ["0010,0020", "12345"],
      ["0020,000D", "1.234.567"],
      ["0020,0010", "59347"]
    ]
    options = {"0008,0020"=>"20061231-20070201",  
      "0008,0030"=>"015500-235559",
      "0008,0050"=>"Abc789",
      "0008,0052"=>"STUDY",
      "0010,0010"=>"Lumberg^Bill",
      "0010,0020"=>"12345",
      "0020,000D"=>"1.234.567",
      "0020,0010"=>"59347"
    }
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
      ["0008,0062", "1.2.645"],
      ["0008,0090", "Dr. House"],
      ["0008,1030", "knee"],
      ["0008,1060", "Dr. Roentgen"],
      ["0008,1080", "cancer"],
      ["0010,0010", ""],
      ["0010,0020", ""],
      ["0010,0021", "Aydee"],
      ["0010,0030", "19560101-19860101"],
      ["0010,0032", "190000-200000"],
      ["0010,0040", "M"],
      ["0010,1000", "Wig"],
      ["0010,1001", "Big"],
      ["0010,1010", "20"],
      ["0010,1020", "155.5"],
      ["0010,1030", "55.5"],
      ["0010,2160", "Eskimo"],
      ["0010,2180", "Salesman"],
      ["0010,21B0", "A long story"],
      ["0010,4000", "Want to go home"],
      ["0020,000D", ""],
      ["0020,0010", ""],
      ["0020,1070", "12"],
      ["0020,1200", "2"],
      ["0020,1202", "5"],
      ["0020,1204", "225"],
      ["0020,1206", "2"],
      ["0020,1208", "97"]
    ]
    options = Hash.new
    data_elements.collect {|element| options[element.first] = element.last}
    @link.expects(:build_data_fragment).with(data_elements, nil)
    @node.find_studies(options)
  end
      
  it "should raise error if unknown query parameter given" do
    @link.stubs(:build_data_fragment)
    lambda {
      @node.find_studies( {"dead,beaf" => "this query parameter is unknown"} )
    }.should raise_error(ArgumentError, /dead,beaf/)
  end

  it "should reset parameters from previous queries" do
    data_elements = [["0008,0020", ""],
      ["0008,0030", ""],
      ["0008,0050", ""],
      ["0008,0052", "STUDY"],
      ["0010,0010", ""],
      ["0010,0020", ""],
      ["0020,000D", ""],
      ["0020,0010", ""]
    ]
    @link.expects(:build_data_fragment).twice.with(data_elements, nil)
    @node.find_studies()
    @node.find_studies()
  end
  
end