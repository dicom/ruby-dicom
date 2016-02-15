# encoding: UTF-8

require 'spec_helper'

module DICOM

  describe DictionaryElement do

    before :example do
      @tag = '0010,0010'
      @name = 'Patient’s Name'
      @vrs = ['PN']
      @vm = '1'
      @retired = ''
      @element = DictionaryElement.new(@tag, @name, @vrs, @vm, @retired)
    end

    describe "::new" do

      it "should successfully create a new instance" do
        expect(@element).to be_a DictionaryElement
      end

      it "should transfer the tag parameter to the :tag attribute" do
        expect(@element.tag).to eql @tag
      end

      it "should transfer the name parameter to the :name attribute" do
        expect(@element.name).to eql @name
      end

      it "should transfer the vrs parameter to the :vrs attribute" do
        expect(@element.vrs).to eql @vrs
      end

      it "should transfer the vm parameter to the :vm attribute" do
        expect(@element.vm).to eql @vm
      end

      it "should transfer the retired parameter to the :retired attribute" do
        expect(@element.retired).to eql @retired
      end

    end


    describe "#private?" do

      it "should return false when the element is not private" do
        expect(@element.private?).to be_falsey
      end

      it "should return true when the element is private" do
        element = DictionaryElement.new('0011,0010', @name, @vrs, @vm, @retired)
        expect(element.private?).to be_truthy
      end

    end


    describe "#retired?" do

      it "should return false when the element is not retired" do
        expect(@element.retired?).to be_falsey
      end

      it "should return true when the element is retired" do
        element = DictionaryElement.new(@tag, @name, @vrs, @vm, 'R')
        expect(element.retired?).to be_truthy
      end

    end


    describe "#vr" do

      it "should return the single VR string when called on an element with only one VR" do
        expect(@element.vr).to eql @vrs[0]
      end

      it "should return the first VR string when called on an element with two VRs" do
        vrs = ['UL', 'SL']
        element = DictionaryElement.new('0011,0010', @name, vrs, @vm, @retired)
        expect(element.vr).to eql vrs[0]
      end

      it "should return the first VR string when called on an element with three VRs" do
        vrs = ['US', 'SS', 'UL']
        element = DictionaryElement.new('0011,0010', @name, vrs, @vm, @retired)
        expect(element.vr).to eql vrs[0]
      end

    end

  end

end