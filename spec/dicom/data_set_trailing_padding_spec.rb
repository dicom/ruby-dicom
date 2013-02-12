# encoding: UTF-8

require 'spec_helper'

module DICOM

  # It has been shown that a DICOM file containing an Data Set Trailing padding element
  # following the image fragments of a DICOM file with compressed pixel data, incorrectly
  # failed to parse. There is some indication that work has to be done on improving the
  # handling of image fragments items, but possibly some special setup needs to be done on
  # this padding element as well. As a quick fix though, we choose to disallow the adding
  # of a padding element to a Sequence on creation.
  #
  describe "With respect to the special Data Set Trailing Padding element" do

    context "Element::new" do

      it "should add itself to a DObject" do
        dcm = DObject.new
        padding = Element.new('FFFC,FFFC', 0, :parent => dcm)
        dcm.exists?('FFFC,FFFC').should be_true
      end

      it "should add itself to an Item" do
        item = Item.new
        padding = Element.new('FFFC,FFFC', 0, :parent => item)
        item.exists?('FFFC,FFFC').should be_true
      end

      it "should not raise an error when trying to add itself to a Sequence" do
        sequence = Sequence.new('0028,3000')
        padding = Element.new('FFFC,FFFC', 0, :parent => sequence)
      end

    end

  end
end