# encoding: UTF-8

require 'spec_helper'

module DICOM

  describe DServer do

    describe '::run' do

      it "should set the attribute timeout equal to the parameter in the block" do
        server = mock("DServer instance")
        server.stubs(:start_scp)
        DServer.stubs(:new).returns(server)
        server.expects(:timeout=).with(100)
        DServer.run(104) do |s|
          s.timeout = 100
        end
      end

      it "should call the method specified in the block" do
        server = mock("DServer instance")
        server.stubs(:start_scp)
        DServer.stubs(:new).returns(server)
        server.expects(:add_abstract_syntax).with("12345")
        DServer.run(104) do |s|
          s.add_abstract_syntax("12345")
        end
      end

    end


    describe '::new' do

      it "should by default set the timeout to 10 seconds" do
        s = DServer.new
        expect(s.timeout).to eql 10
      end

      it "should set the timeout equal to the parameter in the options hash" do
        s = DServer.new(104, :timeout => 100)
        expect(s.timeout).to eql 100
      end

    end

  end

end