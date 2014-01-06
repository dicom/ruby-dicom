# encoding: UTF-8

require 'spec_helper'


module DICOM

  describe Anonymizer do

    before :all do
      DICOM.logger.level = Logger::FATAL
    end

    before :each do
      @anon = TMPDIR + "anon"
      @anon_s = TMPDIR + "anon/"
      @anon_other = TMPDIR + "anon2/"
      @skip = @anon_s + "skip_these"
      @skip_s = @anon_s + "skip_these/"
      @wpath = TMPDIR + "awrite"
      @wpath_s = TMPDIR + "awrite/"
      FileUtils.rmtree(@anon) if File.directory?(@anon)
      FileUtils.rmtree(@anon_other) if File.directory?(@anon_other)
      FileUtils.mkdir_p(@skip)
      FileUtils.mkdir_p(@anon_other)
      FileUtils.copy(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, @anon)
      FileUtils.copy(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, @anon_other)
      FileUtils.copy(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2, @skip)
      FileUtils.copy(DCM_EXPLICIT_MR_RLE_MONO2, @anon)
      FileUtils.copy(DCM_EXPLICIT_MR_RLE_MONO2, @anon_other)
      FileUtils.copy(DCM_EXPLICIT_MR_RLE_MONO2, @skip)
      @anon1 = @anon_s + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @anon2 = @anon_s + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
      @anon3 = @anon_other + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @anon4 = @anon_other + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
      @skip1 = @skip_s + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @skip2 = @skip_s + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
      @w1 = @wpath_s + File.basename(DCM_EXPLICIT_MR_JPEG_LOSSY_MONO2)
      @w2 = @wpath_s + File.basename(DCM_EXPLICIT_MR_RLE_MONO2)
    end

    after :all do
      DICOM.logger.level = Logger::INFO
    end


    describe "#add_exception" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.add_exception(42)}.to raise_error(ArgumentError)
      end

      it "should not anonymize files in the exception directory, but still anonymize the other files (with the given paths ending with a separator)" do
        a = Anonymizer.new
        a.add_exception(@skip_s)
        a.add_folder(@anon_s)
        a.execute
        a1 = DObject.read(@anon1)
        a2 = DObject.read(@anon2)
        s1 = DObject.read(@skip1)
        s2 = DObject.read(@skip2)
        expect(a1.value("0010,0010")).to eql a.value("0010,0010")
        expect(a2.value("0010,0010")).to eql a.value("0010,0010")
        expect(s1.value("0010,0010")).not_to eql a.value("0010,0010")
        expect(s2.value("0010,0010")).not_to eql a.value("0010,0010")
      end

      it "should not anonymize files in the exception directory, but still anonymize the other files (with the given paths not ending with a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.add_exception(@skip)
        a.execute
        a1 = DObject.read(@anon1)
        a2 = DObject.read(@anon2)
        s1 = DObject.read(@skip1)
        s2 = DObject.read(@skip2)
        expect(a1.value("0010,0010")).to eql a.value("0010,0010")
        expect(a2.value("0010,0010")).to eql a.value("0010,0010")
        expect(s1.value("0010,0010")).not_to eql a.value("0010,0010")
        expect(s2.value("0010,0010")).not_to eql a.value("0010,0010")
      end

    end


    describe "#add_folder" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.add_folder(42)}.to raise_error(ArgumentError)
      end

      it "should anonymize files in the specified folder as well as any sub-folders (with the given path ending with a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon_s)
        a.execute
        a1 = DObject.read(@anon1)
        a2 = DObject.read(@anon2)
        s1 = DObject.read(@skip1)
        s2 = DObject.read(@skip2)
        expect(a1.value("0010,0010")).to eql a.value("0010,0010")
        expect(a2.value("0010,0010")).to eql a.value("0010,0010")
        expect(s1.value("0010,0010")).to eql a.value("0010,0010")
        expect(s2.value("0010,0010")).to eql a.value("0010,0010")
      end

      it "should anonymize files in the specified folder as well as any sub-folders (with the given path ending without a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.execute
        a1 = DObject.read(@anon1)
        a2 = DObject.read(@anon2)
        s1 = DObject.read(@skip1)
        s2 = DObject.read(@skip2)
        expect(a1.value("0010,0010")).to eql a.value("0010,0010")
        expect(a2.value("0010,0010")).to eql a.value("0010,0010")
        expect(s1.value("0010,0010")).to eql a.value("0010,0010")
        expect(s2.value("0010,0010")).to eql a.value("0010,0010")
      end

      it "should anonymize files in all specified folders, when multiple folders are added" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.add_folder(@anon_other)
        a.execute
        a1 = DObject.read(@anon1)
        a2 = DObject.read(@anon2)
        a3 = DObject.read(@anon3)
        a4 = DObject.read(@anon4)
        expect(a1.value("0010,0010")).to eql a.value("0010,0010")
        expect(a2.value("0010,0010")).to eql a.value("0010,0010")
        expect(a3.value("0010,0010")).to eql a.value("0010,0010")
        expect(a4.value("0010,0010")).to eql a.value("0010,0010")
      end

    end


    describe "#execute" do

      it "should print information when the logger has been set to a verbose mode" do
        a = Anonymizer.new
        DICOM.logger = Logger.new(LOGDIR + 'anonymizer1.log')
        a.logger.level = Logger::DEBUG
        a.add_folder(@anon_other)
        a.execute
        expect(File.open(LOGDIR + 'anonymizer1.log').readlines.length).to be > 1
      end

      it "should not print information when the logger has been set to a non-verbose mode" do
        a = Anonymizer.new
        DICOM.logger = Logger.new(LOGDIR + 'anonymizer2.log')
        a.logger.level = Logger::UNKNOWN
        a.add_folder(@anon_other)
        a.execute
        expect(File.open(LOGDIR + 'anonymizer2.log').readlines.length).to be <= 1
      end

      it "should anonymize the folder's files according to the list of tags in the anonymization instance" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.execute
        dcm = DObject.read(@anon3)
        expect(dcm.value("0010,0010")).to eql a.value("0010,0010")
        expect(dcm.value("0008,0020")).to eql a.value("0008,0020")
      end

      it "should not create data elements which are present on the 'list to be anonymized' but not in the target file" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.execute
        dcm = DObject.read(@anon3) # the tag we are testing is not originally present in this file
        expect(a.value("0008,0012")).to be_true # make sure the tag we are testing is defined
        expect(dcm.exists?("0008,0012")).to be_false
      end

      it "should fill the log with information" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.logger.expects(:info).at_least_once
        a.execute
      end

      it "should use empty strings for anonymization when we have set the blank attribute as true" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.blank = true
        a.execute
        dcm = DObject.read(@anon3)
        expect(dcm.value("0010,0010")).not_to eql a.value("0010,0010")
        expect(dcm.value("0010,0010").to_s.length).to eql 0
      end

      it "should use enumerated strings for anonymization when we have set the enumeration attribute as true" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.enumeration = true
        a.execute
        a1 = DObject.read(@anon1)
        a2 = DObject.read(@anon2)
        s1 = DObject.read(@skip1)
        s2 = DObject.read(@skip2)
        expect(a1.value("0010,0010")).not_to eql a.value("0010,0010")
        expect(a1.value("0010,0010")).to eql s1.value("0010,0010")
        expect(a2.value("0010,0010")).to eql s2.value("0010,0010")
        expect(a1.value("0010,0010")).not_to eql a2.value("0010,0010")
        expect(s1.value("0010,0010")).not_to eql s2.value("0010,0010")
        expect(a1.value("0010,0010").include?(a.value("0010,0010"))).to be_true
        expect(a1.value("0010,0010")[-1..-1].to_i).not_to eql a2.value("0010,0010")[-1..-1].to_i
      end

      it "should not recursively anonymize the tag hierarchies of the DICOM files when the :recursive option is unused" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.set_tag('0008,0104', :value => 'Recursive')
        a.execute
        dcm = DObject.read(@anon1)
        expect(dcm['0008,2112'][0]['0040,A170'][0].value('0008,0104')).not_to eql 'Recursive'
        expect(dcm['0008,9215'][0].value('0008,0104')).not_to eql 'Recursive'
      end

      it "should recursively anonymize the tag hierarchies of the DICOM files when the :recursive option is used" do
        a = Anonymizer.new(:recursive => true)
        a.add_folder(@anon)
        a.set_tag('0008,0104', :value => 'Recursive')
        a.execute
        dcm = DObject.read(@anon1)
        expect(dcm['0008,2112'][0]['0040,A170'][0].value('0008,0104')).to eql 'Recursive'
        expect(dcm['0008,9215'][0].value('0008,0104')).to eql 'Recursive'
      end

      it "should add a Patient Identity Removed element with value 'YES' to anonymized DICOM objects" do
        a = Anonymizer.new
        a.add_folder(@anon)
        a.execute
        dcm = DObject.read(@anon1)
        expect(dcm.value('0012,0062')).to eql 'YES'
      end

      it "should write the anonymized files to the specified folder and leave the original DICOM files untouched, when the write_path attribute is specified (with the path not ending with a file separator)" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.write_path = @wpath
        dcm = DObject.read(@anon3)
        old_value = dcm.value("0010,0010")
        a.execute
        dcm = DObject.read(@anon3)
        after_value = dcm.value("0010,0010")
        expect(after_value).to eql old_value
        w = DObject.read(@w1)
        expect(w.value("0010,0010")).to eql a.value("0010,0010")
      end

      it "should write the anonymized files to the specified folder (with the path ending with a separator)" do
        a = Anonymizer.new
        a.add_folder(@anon_other)
        a.write_path = @wpath_s
        a.execute
        w = DObject.read(@w1)
        expect(w.value("0010,0010")).to eql a.value("0010,0010")
      end


      context " [:uid]" do

        before :each do
          @dcm = DObject.new
          @dcm.add(Element.new('0010,0010', 'John Doe'))
          @dcm.add(Element.new('0002,0010', '1.2.840.10008.1.2.1'))
          @dcm.add(Element.new('0008,0016', '1.2.840.10008.5.1.4.1.1.2'))
          @dcm.add(Element.new('0008,0018', DICOM.generate_uid))
          @dcm.add(Element.new('0020,000D', DICOM.generate_uid))
          @dcm.add(Element.new('0020,000E', DICOM.generate_uid))
          @dcm.add(Element.new('0020,0052', DICOM.generate_uid))
          @rdcm = DObject.new
          @rdcm.add(Element.new('0010,0010', 'John Doe'))
          @rdcm.add(Element.new('0002,0010', '1.2.840.10008.1.2'))
          @rdcm.add(Element.new('0008,0016', '1.2.840.10008.5.1.4.1.1.4'))
          @rdcm.add(Element.new('0008,0018', DICOM.generate_uid))
          @rdcm.add(Element.new('0020,000D', DICOM.generate_uid))
          @rdcm.add(Element.new('0020,000E', DICOM.generate_uid))
          @rdcm.add(Element.new('0020,0052', DICOM.generate_uid))
          @rdcm.add(Sequence.new('0008,1140'))
          @rdcm['0008,1140'].add_item
          @rdcm['0008,1140'][0].add(Element.new('0008,1150', '1.2.840.10008.5.1.4.1.1.2'))
          @rdcm['0008,1140'][0].add(Element.new('0008,1155', DICOM.generate_uid))
          @dir = "#{TMPDIR}/anon/uid_source/"
          @wdir = "#{TMPDIR}/anon/uid_write1/"
          @dcm.write("#{@dir}/source.dcm")
          @rdcm.write("#{@dir}/ref.dcm")
          @path = "#{@wdir}/source.dcm"
          @rpath = "#{@wdir}/ref.dcm"
        end

        it "should by default keep the original UID values" do
          a = Anonymizer.new(:recursive => true)
          a.add_folder(@dir)
          a.write_path = @wdir
          a.execute
          dcm = DObject.read(@path)
          rdcm = DObject.read(@rpath)
          expect(dcm.value('0008,0016')).to eql @dcm.value('0008,0016')
          expect(dcm.value('0008,0018')).to eql @dcm.value('0008,0018')
          expect(rdcm.value('0008,0016')).to eql @rdcm.value('0008,0016')
          expect(rdcm.value('0008,0018')).to eql @rdcm.value('0008,0018')
          expect(rdcm['0008,1140'][0].value('0008,1150')).to eql @rdcm['0008,1140'][0].value('0008,1150')
          expect(rdcm['0008,1140'][0].value('0008,1155')).to eql @rdcm['0008,1140'][0].value('0008,1155')
        end

        it "should produce a valid Transfer Syntax UID (i.e. not replace it with a random UID), when the :uid option is used" do
          a = Anonymizer.new(:uid => true)
          a.add_folder(@dir)
          a.write_path = @wdir
          a.execute
          dcm = DObject.read(@path)
          rdcm = DObject.read(@rpath)
          expect(LIBRARY.uid(dcm.value('0002,0010')).transfer_syntax?).to be_true
          expect(LIBRARY.uid(rdcm.value('0002,0010')).transfer_syntax?).to be_true
        end

        it "should not touch the SOP Class UID when the :uid option is used" do
          a = Anonymizer.new(:uid => true)
          a.add_folder(@dir)
          a.write_path = @wdir
          a.execute
          dcm = DObject.read(@path)
          rdcm = DObject.read(@rpath)
          expect(dcm.value('0008,0016')).to eql @dcm.value('0008,0016')
          expect(rdcm.value('0008,0016')).to eql @rdcm.value('0008,0016')
        end

=begin
        it "should not touch these UID elements with a VR of UI when the :uid option is used" do
          dcm = DObject.new
          dcm.add(Element.new('0010,0010', 'John Doe'))
          dcm.add(Element.new('0008,0018', DICOM.generate_uid))
          blacklisted_uids = [
            # Private related:
            '0002,0100', '0004,1432',
            # Coding scheme related:
            '0008,010C', '0008,010D',
            # Transfer syntax related:
            '0002,0010', '0400,0010', '0400,0510', '0004,1512',
            # SOP class related:
            '0000,0002', '0000,0003', '0002,0002', '0004,1510', '0004,151A', '0008,0016',
            '0008,001A', '0008,001B', '0008,0062', '0008,1150', '0008,115A'
          ]
          blacklisted_uids.each do |uid|
            e = Element.new(uid, DICOM.generate_uid, :parent => dcm)
            e.expects(:'value=').never
          end
          a = Anonymizer.new(:uid => true)
          a.anonymize
        end
=end

        it "should replace all relevant UIDs when both the :uid and :recursive options are used" do
          a = Anonymizer.new(:recursive => true, :uid => true)
          a.add_folder(@dir)
          a.write_path = @wdir
          a.execute
          dcm = DObject.read(@path)
          rdcm = DObject.read(@rpath)
          expect(dcm.value('0008,0018')).not_to eql @dcm.value('0008,0018')
          expect(dcm.value('0020,000D')).not_to eql @dcm.value('0020,000D')
          expect(dcm.value('0020,000E')).not_to eql @dcm.value('0020,000E')
          expect(dcm.value('0020,0052')).not_to eql @dcm.value('0020,0052')
          expect(rdcm.value('0008,0018')).not_to eql @rdcm.value('0008,0018')
          expect(rdcm.value('0020,000D')).not_to eql @rdcm.value('0020,000D')
          expect(rdcm.value('0020,000E')).not_to eql @rdcm.value('0020,000E')
          expect(rdcm.value('0020,0052')).not_to eql @rdcm.value('0020,0052')
          expect(rdcm['0008,1140'][0].value('0008,1155')).not_to eql @rdcm['0008,1140'][0].value('0008,1155')
        end

      end

      context " [:audit_trail]" do

        it "should write an audit trail file" do
          audit_file = TMPDIR + "anonymization1.json"
          a = Anonymizer.new(:audit_trail => audit_file)
          a.add_folder(@anon_other)
          a.write_path = @wpath_s
          a.enumeration = true
          a.execute
          expect(File.exists?(audit_file)).to be_true
          at = AuditTrail.read(audit_file)
          expect(at).to be_a AuditTrail
        end

        it "should encrypt the values stored in the audit trail file" do
          audit_file = TMPDIR + "anonymization_encrypted.json"
          a = Anonymizer.new(:audit_trail => audit_file, :encryption => true)
          a.add_folder(@anon_other)
          a.write_path = @wpath_s
          a.enumeration = true
          a.execute
          at = AuditTrail.read(audit_file)
          names = at.records('0010,0010').to_a
          # MD5 hashes are 32 characters long:
          expect(names.first[0].length).to eql 32
          expect(names.last[0].length).to eql 32
          # Values should be the ordinary, enumerated ones:
          expect(names.first[1]).to eql 'Patient1'
          expect(names.last[1]).to eql 'Patient2'
        end

      end

    end


    describe "#delete_tag" do

      it "should delete tags marked for deletion during anonymization" do
        a = Anonymizer.new
        dcm = DObject.read(@anon3)
        expect(dcm.exists?("0010,0010")).to be_true
        a.add_folder(@anon_other)
        a.delete_tag("0010,0010")
        a.execute
        dcm = DObject.read(@anon3)
        expect(dcm.exists?("0010,0010")).to be_false
      end

    end

  end

end
