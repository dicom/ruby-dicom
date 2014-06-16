# encoding: UTF-8

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
        expect(@uid).to be_a UID
      end

      it "should transfer the value parameter to the :value attribute" do
        expect(@uid.value).to eql @value
      end

      it "should transfer the name parameter to the :name attribute" do
        expect(@uid.name).to eql @name
      end

      it "should transfer the type parameter to the :type attribute" do
        expect(@uid.type).to eql @type
      end

      it "should transfer the retired parameter to the :retired attribute" do
        expect(@uid.retired).to eql @retired
      end

    end


    context "#big_endian?" do

      it "should return false for this non-transfer syntax (SOP Class) value" do
        uid = LIBRARY.uid('1.2.840.10008.1.1')
        expect(uid.big_endian?).to be_falsey
      end

      it "should return false for the default implicit little endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2')
        expect(uid.big_endian?).to be_falsey
      end

      it "should return false for the explicit little endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.1')
        expect(uid.big_endian?).to be_falsey
      end

      it "should return false for the deflated explicit little endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.1.99')
        expect(uid.big_endian?).to be_falsey
      end

      it "should return true for the explicit big endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.2')
        expect(uid.big_endian?).to be_truthy
      end

      it "should return false for a compressed pixel data transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.4.58')
        expect(uid.big_endian?).to be_falsey
      end

    end


    context "#compressed_pixels?" do

      it "should return false for this non-transfer syntax (SOP Class) value" do
        uid = LIBRARY.uid('1.2.840.10008.1.1')
        expect(uid.compressed_pixels?).to be_falsey
      end

      it "should return false for this uncompressed transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2')
        expect(uid.compressed_pixels?).to be_falsey
      end

      it "should return true for this compressed transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.4.64')
        expect(uid.compressed_pixels?).to be_truthy
      end

      it "should return false for this transfer syntax where the dicom file itself, not the pixel data, is compressed" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.1.99')
        expect(uid.compressed_pixels?).to be_falsey
      end

    end


    context "#explicit?" do

      it "should return false for this non-transfer syntax (SOP Class) value" do
        uid = LIBRARY.uid('1.2.840.10008.1.1')
        expect(uid.explicit?).to be_falsey
      end

      it "should return false for the default implicit little endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2')
        expect(uid.explicit?).to be_falsey
      end

      it "should return true for the explicit little endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.1')
        expect(uid.explicit?).to be_truthy
      end

      it "should return true for the deflated explicit little endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.1.99')
        expect(uid.explicit?).to be_truthy
      end

      it "should return true for the explicit big endian transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.2')
        expect(uid.explicit?).to be_truthy
      end

      it "should return true for a compressed pixel data transfer syntax" do
        uid = LIBRARY.uid('1.2.840.10008.1.2.4.58')
        expect(uid.explicit?).to be_truthy
      end

    end


    context "#retired?" do

      it "should return false when the UID is not retired" do
        expect(@uid.retired?).to be_falsey
      end

      it "should return true when the uid is retired" do
        uid = UID.new(@value, @name, @type, 'R')
        expect(uid.retired?).to be_truthy
      end

    end


    context "#sop_class?" do

      it "should return false when the UID is not a SOP Class" do
        uid = UID.new('1.2.840.10008.1.2.1', 'Explicit VR Little Endian', 'Transfer Syntax', '')
        expect(uid.sop_class?).to be_falsey
      end

      it "should return true when the UID is a SOP Class" do
        expect(@uid.sop_class?).to be_truthy
      end

    end


    context "#transfer_syntax?" do

      it "should return false when the UID is not a Transfer Syntax" do
        expect(@uid.transfer_syntax?).to be_falsey
      end

      it "should return true when the UID is a Transfer Syntax" do
        uid = UID.new('1.2.840.10008.1.2.1', 'Explicit VR Little Endian', 'Transfer Syntax', '')
        expect(uid.transfer_syntax?).to be_truthy
      end

    end

  end

end