# encoding: ASCII-8BIT

require 'spec_helper'

module DICOM

  describe DictionaryElement do

    before :each do
      @tag = '0010,0010'
      @name = 'Patient’s Name'
      @vrs = ['PN']
      @vm = '1'
      @retired = ''
      @element = DictionaryElement.new(@tag, @name, @vrs, @vm, @retired)
    end

    context "::new" do

      it "should successfully create a new instance" do
        @element.should be_a DictionaryElement
      end

      it "should transfer the tag parameter to the :tag attribute" do
        @element.tag.should eql @tag
      end

      it "should transfer the name parameter to the :name attribute" do
        @element.name.should eql @name
      end

      it "should transfer the vrs parameter to the :vrs attribute" do
        @element.vrs.should eql @vrs
      end

      it "should transfer the vm parameter to the :vm attribute" do
        @element.vm.should eql @vm
      end

      it "should transfer the retired parameter to the :retired attribute" do
        @element.retired.should eql @retired
      end

    end


    context "#private?" do

      it "should return false when the element is not private" do
        @element.private?.should be_false
      end

      it "should return true when the element is private" do
        element = DictionaryElement.new('0011,0010', @name, @vrs, @vm, @retired)
        element.private?.should be_true
      end

    end


    context "#retired?" do

      it "should return false when the element is not retired" do
        @element.retired?.should be_false
      end

      it "should return true when the element is retired" do
        element = DictionaryElement.new(@tag, @name, @vrs, @vm, 'R')
        element.retired?.should be_true
      end

    end


    context "#vr" do

      it "should return the single VR string when called on an element with only one VR" do
        @element.vr.should eql @vrs[0]
      end

      it "should return the first VR string when called on an element with two VRs" do
        vrs = ['UL', 'SL']
        element = DictionaryElement.new('0011,0010', @name, vrs, @vm, @retired)
        element.vr.should eql vrs[0]
      end

      it "should return the first VR string when called on an element with three VRs" do
        vrs = ['US', 'SS', 'UL']
        element = DictionaryElement.new('0011,0010', @name, vrs, @vm, @retired)
        element.vr.should eql vrs[0]
      end

    end

  end

end