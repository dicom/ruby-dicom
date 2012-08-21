# encoding: ASCII-8BIT

require 'spec_helper'

module DICOM

  describe UID do

    before :each do
      @value = '1.2.840.10008.1.1'
      @name = 'Verification SOP Class'
      @type = 'SOP Class'
      @retired = ''
      @uid = UID.new(@value, @name, @type, @retired)
    end

    context "::new" do

      it "should successfully create a new instance" do
        @uid.should be_a UID
      end

      it "should transfer the value parameter to the :value attribute" do
        @uid.value.should eql @value
      end

      it "should transfer the name parameter to the :name attribute" do
        @uid.name.should eql @name
      end

      it "should transfer the type parameter to the :type attribute" do
        @uid.type.should eql @type
      end

      it "should transfer the retired parameter to the :retired attribute" do
        @uid.retired.should eql @retired
      end

    end


    context "#retired?" do

      it "should return false when the UID is not retired" do
        @uid.retired?.should be_false
      end

      it "should return true when the uid is retired" do
        uid = UID.new(@value, @name, @type, 'R')
        uid.retired?.should be_true
      end

    end


    context "#sop_class?" do

      it "should return false when the UID is not a SOP Class" do
        uid = UID.new('1.2.840.10008.1.2.1', 'Explicit VR Little Endian', 'Transfer Syntax', '')
        uid.sop_class?.should be_false
      end

      it "should return true when the UID is a SOP Class" do
        @uid.sop_class?.should be_true
      end

    end


    context "#transfer_syntax?" do

      it "should return false when the UID is not a Transfer Syntax" do
        @uid.transfer_syntax?.should be_false
      end

      it "should return true when the UID is a Transfer Syntax" do
        uid = UID.new('1.2.840.10008.1.2.1', 'Explicit VR Little Endian', 'Transfer Syntax', '')
        uid.transfer_syntax?.should be_true
      end

    end

  end

end