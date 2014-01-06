# encoding: UTF-8

require 'spec_helper'


module DICOM

  describe Anonymizer do

    before :all do
      DICOM.logger.level = Logger::FATAL
    end

    before :each do
      #DICOM.logger = Logger.new(STDOUT)
      #DICOM.logger.level = Logger::FATAL
      @a = Anonymizer.new
      # Create a couple of DICOM objects for test purposes:
      @dcm1 = DObject.new
      @dcm2 = DObject.new
      # Separate attributes:
      # CT image:
      @dcm1.add(Element.new('0008,0008', 'ORIGINAL\PRIMARY\AXIAL'))
      @dcm1.add(Element.new('0008,0016', '1.2.840.10008.5.1.4.1.1.2'))
      @dcm1.add(Element.new('0008,0018', '1.3.666.1.77'))
      @dcm1.add(Element.new('0008,0023', '20112207'))
      @dcm1.add(Element.new('0008,0033', '150411'))
      @dcm1.add(Element.new('0008,0060', 'CT'))
      @dcm1.add(Element.new('0020,000D', '1.3.666.1.22'))
      @dcm1.add(Element.new('0020,000E', '1.3.666.1.44'))
      @dcm1.add(Element.new('0020,0011', '1'))
      @dcm1.add(Element.new('0020,0052', '1.3.666.1.55'))
      @dcm1.add(Element.new('0020,4000', 'Lateral tumor'))
      # Structure set:
      @dcm2.add(Element.new('0008,0016', '1.2.840.10008.5.1.4.1.1.481.3'))
      @dcm2.add(Element.new('0008,0018', '1.3.666.2.88'))
      @dcm2.add(Element.new('0008,0060', 'RTSTRUCT'))
      @dcm2.add(Element.new('0020,000D', '1.3.666.1.22'))
      @dcm2.add(Element.new('0020,000E', '1.3.666.2.66'))
      @dcm2.add(Element.new('0020,0011', '2'))
      # UID reference from dcm2 to dcm1:
      @dcm2.add(Sequence.new('3006,0010'))
      @dcm2['3006,0010'].add_item
      @dcm2['3006,0010'][0].add(Element.new('0020,0052', '1.3.666.1.55'))
      @dcm2['3006,0010'][0].add(Sequence.new('3006,0012'))
      @dcm2['3006,0010'][0]['3006,0012'].add_item
      @dcm2['3006,0010'][0]['3006,0012'][0].add(Element.new('0008,1150', '1.2.840.10008.5.1.4.1.1.2'))
      @dcm2['3006,0010'][0]['3006,0012'][0].add(Element.new('0008,1155', '1.3.666.1.22'))
      @dcm2['3006,0010'][0]['3006,0012'][0].add(Sequence.new('3006,0014'))
      @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'].add_item
      @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0].add(Element.new('0020,000E', '1.3.666.1.44'))
      @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0].add(Sequence.new('3006,0016'))
      @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'].add_item
      @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'][0].add(Element.new('0008,1150', '1.2.840.10008.5.1.4.1.1.2'))
      @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'][0].add(Element.new('0008,1155', '1.3.666.1.77'))
      # Common attributes:
      [@dcm1, @dcm2].each do |dcm|
        dcm.add(Element.new('0008,0005', 'ISO_IR 100'))
        dcm.add(Element.new('0008,0012', '20113007'))
        dcm.add(Element.new('0008,0013', '123300'))
        dcm.add(Element.new('0008,0020', '20112207'))
        dcm.add(Element.new('0008,0030', '145901'))
        dcm.add(Element.new('0008,0050', '53'))
        dcm.add(Element.new('0008,0070', 'Isengard'))
        dcm.add(Element.new('0008,0080', 'Mordor Care'))
        dcm.add(Element.new('0008,0090', 'Dr. Shelob'))
        dcm.add(Element.new('0008,1010', 'Plan unit'))
        dcm.add(Element.new('0008,103E', 'Follow up scan'))
        dcm.add(Element.new('0008,1040', 'Orc Cancer Ward'))
        dcm.add(Element.new('0008,1070', 'Sarumann'))
        dcm.add(Element.new('0008,1090', 'Middle Earth Medical'))
        dcm.add(Element.new('0010,0010', 'Lt Gothmog'))
        dcm.add(Element.new('0010,0020', '12345 9876'))
        dcm.add(Element.new('0010,0030', '19751029'))
        dcm.add(Element.new('0010,0040', 'M'))
        dcm.add(Element.new('0018,1020', 'RingScan V2.2'))
        dcm.add(Element.new('0020,0010', '4304'))
        # Meta header:
        dcm.add(Element.new('0002,0001', [0,1]))
        dcm.add(Element.new('0002,0002', dcm.value('0008,0016')))
        dcm.add(Element.new('0002,0003', dcm.value('0008,0018')))
        dcm.add(Element.new('0002,0010', EXPLICIT_LITTLE_ENDIAN))
        dcm.add(Element.new('0002,0012', '1.3.666'))
        dcm.add(Element.new('0002,0013', 'mordorlib 1.0.1'))
        dcm.add(Element.new('0002,0016', 'RingScan'))
        dcm.add(Element.new('0002,0000', dcm.send(:meta_group_length)))
      end
    end

    after :all do
      DICOM.logger.level = Logger::INFO
    end


    describe "::new" do

      it "should by default set the audit_trail attribute as nil" do
        expect(@a.audit_trail).to be_nil
      end

      it "should by default set the audit_trail_file attribute as nil" do
        expect(@a.audit_trail_file).to be_nil
      end

      it "should by default set the blank attribute as false" do
        expect(@a.blank).to be_false
      end

      it "should by default set the delete attribute as an empty hash" do
        expect(@a.delete).to eql Hash.new
      end

      it "should by default set the delete_private attribute as false" do
        expect(@a.delete_private).to be_false
      end

      it "should by default set the encryption attribute as nil" do
        expect(@a.encryption).to be_nil
      end

      it "should by default set the enumeration attribute as false" do
        expect(@a.enumeration).to be_false
      end

      it "should by default set the logger_level attribute as Logger::FATAL" do
        expect(@a.logger_level).to eql Logger::FATAL
      end

      it "should by default set the random_file_name attribute as nil" do
        expect(@a.random_file_name).to be_nil
      end

      it "should by default set the recursive attribute as nil" do
        expect(@a.recursive).to be_nil
      end

      it "should by default set the uid attribute as nil" do
        expect(@a.uid).to be_nil
      end

      it "should by default set the uid_root attribute as the DICOM module's UID_ROOT constant" do
        expect(@a.uid_root).to eql UID_ROOT
      end

      it "should by default set the write_path attribute as nil" do
        expect(@a.write_path).to be_nil
      end

      it "should pass the :audit_trail option to the 'audit_trail_file' attribute" do
        trail_file = 'audit_trail.json'
        a = Anonymizer.new(:audit_trail => trail_file)
        expect(a.audit_trail_file).to eql trail_file
      end

      it "should pass the :blank option to the 'blank' attribute" do
        a = Anonymizer.new(:blank => true)
        expect(a.blank).to be_true
      end

      it "should pass the :delete_private option to the 'delete_private' attribute" do
        a = Anonymizer.new(:delete_private => true)
        expect(a.delete_private).to be_true
      end

      it "should pass the :encryption option to the 'encryption' attribute when a Digest class is passed (along with the :audit_trail option)" do
        require 'digest'
        a = Anonymizer.new(:audit_trail => 'audit_trail.json', :encryption => Digest::SHA256)
        expect(a.encryption).to eql Digest::SHA256
      end

      it "should pass the :enumeration option to the 'enumeration' attribute" do
        a = Anonymizer.new(:enumeration => true)
        expect(a.enumeration).to be_true
      end

      it "should pass the :logger_level option to the 'logger_level' attribute" do
        a = Anonymizer.new(:logger_level => Logger::DEBUG)
        expect(a.logger_level).to eql Logger::DEBUG
      end

      it "should pass the :random_file_name option to the 'random_file_name' attribute" do
        a = Anonymizer.new(:random_file_name => true)
        expect(a.random_file_name).to be_true
      end

      it "should pass the :recursive option to the 'recursive' attribute" do
        a = Anonymizer.new(:recursive => true)
        expect(a.recursive).to be_true
      end

      it "should pass the :uid option to the 'uid' attribute" do
        a = Anonymizer.new(:uid => true)
        expect(a.uid).to be_true
      end

      it "should pass the :uid_root option to the 'uid_root' attribute" do
        custom_uid = '1.999.5'
        a = Anonymizer.new(:uid_root => custom_uid)
        expect(a.uid_root).to eql custom_uid
      end

      it "should pass the :write_path option to the 'write_path' attribute" do
        a = Anonymizer.new(:write_path => true)
        expect(a.write_path).to be_true
      end

      it "should set MD5 as the default Digest class when an :encryption option that is not a Digest class is given (along with the :audit_trail option)" do
        a = Anonymizer.new(:audit_trail => 'audit_trail.json', :encryption => true)
        expect(a.encryption).to eql Digest::MD5
      end

      it "should load an AuditTrail instance to the 'audit_trail' attribute when the :audit_trail option is used" do
        a = Anonymizer.new(:audit_trail => 'audit_trail.json')
        expect(a.audit_trail).to be_an AuditTrail
      end

    end


    describe "#==()" do

      it "should be true when comparing two instances having the same attribute values" do
        a1 = Anonymizer.new
        a2 = Anonymizer.new
        expect(a1 == a2).to be_true
      end

      it "should be false when comparing two instances having different attribute values (different children)" do
        a1 = Anonymizer.new
        a2 = Anonymizer.new(:blank => true)
        expect(a1 == a2).to be_false
      end

      it "should be false when comparing against an instance of incompatible type" do
        a = Anonymizer.new
        expect(a == 42).to be_false
      end

    end


    describe "#eql?" do

      it "should be true when comparing two instances having the same attribute values" do
        a1 = Anonymizer.new
        a2 = Anonymizer.new
        expect(a1.eql?(a2)).to be_true
      end

      it "should be false when comparing two instances having different attribute values" do
        a1 = Anonymizer.new
        a2 = Anonymizer.new
        a2.set_tag('0008,0042', :value => 'Alpha')
        expect(a1.eql?(a2)).to be_false
      end

    end


    describe "#anonymize" do

      it "should raise an ArgumentError when a non-string/non-dcm is passed as an argument" do
        a = Anonymizer.new
        expect {a.anonymize(42)}.to raise_error(ArgumentError)
      end

      it "should return an empty array when given an invalid DICOM string" do
        a = Anonymizer.new
        res = a.anonymize('asdf'*20)
        expect(res.class).to eql Array
        expect(res.length).to eql 0
      end

      it "should return an array with the single DObject instance" do
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        expect(res.class).to eql Array
        expect(res.length).to eql 1
        expect(res[0].object_id).to  eql @dcm1.object_id
      end

      it "should return an array with the two DObject instances" do
        a = Anonymizer.new
        res = a.anonymize([@dcm1, @dcm2])
        expect(res.length).to eql 2
        expect(res[0].object_id).to  eql @dcm1.object_id
        expect(res[1].object_id).to  eql @dcm2.object_id
      end

      it "should replace values selected for anonymization" do
        original = @dcm1.value('0010,0010')
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        adcm = res[0]
        expect(adcm.value('0010,0010')).not_to eql original
        expect(adcm.value('0010,0010')).to eql a.value('0010,0010')
      end

      it "should not modify values which are not selected for anonymization" do
        original = @dcm1.value('0008,0060')
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        adcm = res[0]
        expect(adcm.value('0008,0060')).to eql original
      end

      it "should not create data elements which are selected for anonymization, but not present in the actual DICOM object" do
        a = Anonymizer.new
        tag = '0018,1160'
        a.set_tag(tag)
        # Ensure the element is not originally present (as that would ruin the test):
        expect(@dcm1.exists?(tag)).to be_false
        res = a.anonymize(@dcm1)
        # Ensure it is still not present in the anonymized object:
        expect(res[0].exists?(tag)).to be_false
      end

      it "should use empty strings for anonymization when the blank attribute is set" do
        a = Anonymizer.new(:blank => true)
        res = a.anonymize(@dcm1)
        expect(res[0].value('0010,0010')).to eql ''
      end

      it "should use enumerated strings when the enumeration attribute is set" do
        @dcm1['0010,0010'].value = 'Joe Schmoe'
        @dcm2['0010,0010'].value = 'Jack Schmack'
        a = Anonymizer.new(:enumeration => true)
        res = a.anonymize([@dcm1, @dcm2])
        expect(res[0].value('0010,0010')).to eql 'Patient1'
        expect(res[1].value('0010,0010')).to eql 'Patient2'
      end

      it "should only anonymize top level data elements when the :recursive option is unused" do
        original = @dcm1.value('0010,0010')
        @dcm1.add(Sequence.new('0008,0082'))
        @dcm1['0008,0082'].add_item
        @dcm1['0008,0082'][0].add(Element.new('0010,0010', original))
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        adcm = res[0]
        expect(adcm['0008,0082'][0].value('0010,0010')).to eql original
      end

      it "should recursively anonymize all tag levels when the :recursive option is set" do
        original = @dcm1.value('0010,0010')
        @dcm1.add(Sequence.new('0008,0082'))
        @dcm1['0008,0082'].add_item
        @dcm1['0008,0082'][0].add(Element.new('0010,0010', original))
        a = Anonymizer.new(:recursive => true)
        res = a.anonymize(@dcm1)
        adcm = res[0]
        expect(adcm['0008,0082'][0].value('0010,0010')).not_to eql original
      end

      it "should by default keep original UID values" do
        original_sop = @dcm1.value('0008,0018')
        original_study = @dcm1.value('0020,000D')
        original_series = @dcm1.value('0020,000E')
        original_frame = @dcm1.value('0020,0052')
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        expect(res[0].value('0008,0018')).to eql original_sop
        expect(res[0].value('0020,000D')).to eql original_study
        expect(res[0].value('0020,000E')).to eql original_series
        expect(res[0].value('0020,0052')).to eql original_frame
      end

      it "should replace the relevant (top level) UIDs when the :uid option is set" do
        original_sop = @dcm2.value('0008,0018')
        original_study = @dcm2.value('0020,000D')
        original_series = @dcm2.value('0020,000E')
        original_frame_ref = @dcm2['3006,0010'][0].value('0020,0052')
        original_study_ref = @dcm2['3006,0010'][0]['3006,0012'][0].value('0008,1155')
        original_series_ref = @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0].value('0020,000E')
        original_sop_ref = @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'][0].value('0008,1155')
        a = Anonymizer.new(:uid => true)
        res = a.anonymize(@dcm2)
        adcm = res[0]
        expect(adcm.value('0008,0018')).not_to eql original_sop
        expect(adcm.value('0020,000D')).not_to eql original_study
        expect(adcm.value('0020,000E')).not_to eql original_series
        expect(adcm['3006,0010'][0].value('0020,0052')).to eql original_frame_ref
        expect(adcm['3006,0010'][0]['3006,0012'][0].value('0008,1155')).to eql original_study_ref
        expect(adcm['3006,0010'][0]['3006,0012'][0]['3006,0014'][0].value('0020,000E')).to eql original_series_ref
        expect(adcm['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'][0].value('0008,1155')).to eql original_sop_ref
      end

      it "should recursively replace the relevant UIDs at all tag levels when both the :uid & :recursive options are set" do
        original_sop = @dcm2.value('0008,0018')
        original_study = @dcm2.value('0020,000D')
        original_series = @dcm2.value('0020,000E')
        original_frame_ref = @dcm2['3006,0010'][0].value('0020,0052')
        original_study_ref = @dcm2['3006,0010'][0]['3006,0012'][0].value('0008,1155')
        original_series_ref = @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0].value('0020,000E')
        original_sop_ref = @dcm2['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'][0].value('0008,1155')
        a = Anonymizer.new(:recursive => true, :uid => true)
        res = a.anonymize(@dcm2)
        adcm = res[0]
        expect(adcm.value('0008,0018')).not_to eql original_sop
        expect(adcm.value('0020,000D')).not_to eql original_study
        expect(adcm.value('0020,000E')).not_to eql original_series
        expect(adcm['3006,0010'][0].value('0020,0052')).not_to eql original_frame_ref
        expect(adcm['3006,0010'][0]['3006,0012'][0].value('0008,1155')).not_to eql original_study_ref
        expect(adcm['3006,0010'][0]['3006,0012'][0]['3006,0014'][0].value('0020,000E')).not_to eql original_series_ref
        expect(adcm['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'][0].value('0008,1155')).not_to eql original_sop_ref
      end

      it "should not randomize 'static' UIDs (like e.g. Transfer Syntax and SOP Class UID) when the :uid option is set" do
        static_uids = Array.new
        static_uids << Element.new('0008,010C', '1.234.77', :parent => @dcm1)
        static_uids << Element.new('0008,010D', '1.234.66', :parent => @dcm1)
        static_uids << Element.new('0008,0016', '1.234.55', :parent => @dcm1)
        static_uids << Element.new('0008,001A', '1.234.44', :parent => @dcm1)
        static_uids << Element.new('0008,001B', '1.234.33', :parent => @dcm1)
        static_uids << Element.new('0008,0062', '1.234.22', :parent => @dcm1)
        static_uids << Element.new('0008,1150', '1.234.11', :parent => @dcm1)
        static_uids << Element.new('0008,115A', '1.234.98', :parent => @dcm1)
        static_uids << Element.new('0400,0010', '1.234.97', :parent => @dcm1)
        static_uids << Element.new('0400,0510', '1.234.96', :parent => @dcm1)
        a = Anonymizer.new(:uid => true)
        res = a.anonymize(@dcm1)
        static_uids.each do |blacklisted_uid|
          expect(res[0].value(blacklisted_uid.tag)).to eql blacklisted_uid.value
        end
      end

      it "should preserve inter-file relationships of equally tagged UIDs (keeping references valid in series & studies), when the :uid, :audit_trail (& :recursive) options are set" do
        file_name = File.join(TMPDIR, "anonymization/uid_relations_equal_tags.json")
        original_study = @dcm1.value('0020,000D')
        a = Anonymizer.new(:audit_trail => file_name, :recursive => true, :uid => true)
        res = a.anonymize([@dcm1, @dcm2])
        expect(res[1].value('0020,000D')).not_to eql original_study
        expect(res[1].value('0020,000D')).to eql res[0].value('0020,000D')
        expect(res[1]['3006,0010'][0].value('0020,0052')).to eql res[0].value('0020,0052')
        expect(res[1]['3006,0010'][0]['3006,0012'][0]['3006,0014'][0].value('0020,000E')).to eql res[0].value('0020,000E')
      end

      it "should preserve inter-file relationships of differently tagged UIDs (keeping references valid in series & studies), when the :uid, :audit_trail (& :recursive) options are set" do
        file_name = File.join(TMPDIR, "anonymization/uid_relations_different_tags.json")
        original_study = @dcm1.value('0020,000D')
        a = Anonymizer.new(:audit_trail => file_name, :recursive => true, :uid => true)
        res = a.anonymize([@dcm1, @dcm2])
        expect(res[1].value('0020,000D')).not_to eql original_study
        expect(res[1]['3006,0010'][0]['3006,0012'][0].value('0008,1155')).to eql res[0].value('0020,000D')
        expect(res[1]['3006,0010'][0]['3006,0012'][0]['3006,0014'][0]['3006,0016'][0].value('0008,1155')).to eql res[0].value('0008,0018')
      end

      it "should write an audit trail file when the :audit_trail (and :enumeration) option is set" do
        file_name = File.join(TMPDIR, "anonymization/audit_trail.json")
        a = Anonymizer.new(:audit_trail => file_name, :enumeration => true)
        a.anonymize(@dcm1)
        expect(File.exists?(file_name)).to be_true
        at = AuditTrail.read(file_name)
        expect(at).to be_a AuditTrail
      end

      it "should use encrypted key values in the audit trail file when the :audit_trail, :encryption (and :enumeration) options are set" do
        file_name = File.join(TMPDIR, "anonymization/encrypted_audit_trail.json")
        a = Anonymizer.new(:audit_trail => file_name, :encryption => true, :enumeration => true)
        @dcm2['0010,0010'].value = 'Joe Schmoe'
        a.anonymize([@dcm1, @dcm2])
        at = AuditTrail.read(file_name)
        names = at.records('0010,0010').to_a
        # MD5 hashes are 32 characters long:
        expect(names.first[0].length).to eql 32
        expect(names.last[0].length).to eql 32
        # Values should be the ordinary, enumerated ones:
        expect(names.first[1]).to eql 'Patient1'
        expect(names.last[1]).to eql 'Patient2'
      end

      it "should add a Patient Identity Removed element with value 'YES' to anonymized DICOM object" do
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        expect(res[0].value('0012,0062')).to eql 'YES'
      end

      it "should anonymize and rewrite the DICOM file (given by its file name string)" do
        file_name = File.join(TMPDIR, "anonymization/example_01/test.dcm")
        @dcm1.write(file_name)
        a = Anonymizer.new
        a.anonymize(file_name)
        dcm1 = DObject.read(file_name)
        expect(dcm1.value('0010,0010')).not_to eql @dcm1.value('0010,0010')
        expect(dcm1.value('0010,0010')).to eql a.value('0010,0010')
      end

      it "should anonymize and rewrite the DICOM file (given by its directory path string)" do
        file_name = File.join(TMPDIR, "anonymization/example_02/test.dcm")
        @dcm1.write(file_name)
        a = Anonymizer.new
        a.anonymize(File.dirname(file_name))
        dcm1 = DObject.read(file_name)
        expect(dcm1.value('0010,0010')).not_to eql @dcm1.value('0010,0010')
        expect(dcm1.value('0010,0010')).to eql a.value('0010,0010')
      end

      it "should write the anonymized DICOM file to the separate directory (as given by the :write_path option)" do
        file_name = File.join(TMPDIR, "anonymization/example_03/test.dcm")
        write_path = File.join(TMPDIR, "anonymization/example_03/write")
        @dcm1.write(file_name)
        a = Anonymizer.new(:write_path => write_path)
        a.anonymize(file_name)
        dicom = DICOM.load(write_path)
        original = DObject.read(file_name)
        expect(original.value('0010,0010')).to eql @dcm1.value('0010,0010')
        expect(dicom.length).to eql 1
        expect(dicom[0].value('0010,0010')).not_to eql @dcm1.value('0010,0010')
      end

      it "should by default keep the original file name when writing an anonymized file to a separate location" do
        file_name = File.join(TMPDIR, "anonymization/example_04/test.dcm")
        write_path = File.join(TMPDIR, "anonymization/example_04/write")
        @dcm1.write(file_name)
        a = Anonymizer.new(:write_path => write_path)
        a.anonymize(file_name)
        expect(File.exists?(File.join(write_path, File.basename(file_name)))).to be_true
      end

      it "should use a random file name (but still with a .dcm extension) when the :random_file_name option is used" do
        file_name = File.join(TMPDIR, "anonymization/example_05/test.dcm")
        write_path = File.join(TMPDIR, "anonymization/example_05/write")
        @dcm1.write(file_name)
        a = Anonymizer.new(:random_file_name => true, :write_path => write_path)
        a.anonymize(file_name)
        files = Dir[File.join(write_path, '**/*')]
        expect(files.length).to eql 1
        expect(File.extname(files[0])).to eql '.dcm'
        expect(File.exists?(File.join(write_path, File.basename(file_name)))).to be_false
      end

    end


    describe "#delete_tag" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.delete_tag(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.delete_tag('asdf,asdf')}.to raise_error(ArgumentError)
      end

      it "should add the given tag to the Anonymizer's delete attribute hash" do
        a = Anonymizer.new
        tag = '0010,0010'
        expect(a.delete[tag]).to be_false
        a.delete_tag(tag)
        expect(a.delete[tag]).to be_true
      end

    end


    describe "#enum" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value('asdf,asdf')}.to raise_error(ArgumentError)
      end

      it "should return the enumeration boolean for the specified tag" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :enum => true)
        expect(a.enum('0010,0010')).to be_true
        a.set_tag('0010,0010', :enum => false)
        expect(a.enum('0010,0010')).to be_false
        a.set_tag('0010,0010', :enum => true)
        expect(a.enum('0010,0010')).to be_true
      end

    end


    context "#hash" do

      it "should return the same Fixnum for two instances having the same attribute values" do
        a1 = Anonymizer.new
        a2 = Anonymizer.new
        expect(a1.hash).to be_a Fixnum
        expect(a1.hash).to eql a2.hash
      end

      it "should return a different Fixnum for two instances having different attribute values" do
        a1 = Anonymizer.new
        a2 = Anonymizer.new(:write_path => 'tmp')
        expect(a1.hash).not_to eql a2.hash
      end

    end


    # FIXME? Currently there is no specification for the format of the element printout (this method is not very important, really).
    #
    describe "#print" do

      it "should print information to the screen" do
        a = Anonymizer.new
        a.expects(:puts).at_least_once
        a.print
      end

    end


    describe "#remove_tag" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.remove_tag(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.remove_tag('asdf,asdf')}.to raise_error(ArgumentError)
      end

      it "should remove the tag, with its value and enumeration status, from the list of tags to be anonymized" do
        a = Anonymizer.new
        a.remove_tag('0010,0010')
        expect(a.value('0010,0010')).to be_nil
        expect(a.enum('0010,0010')).to be_nil
      end

    end


    describe "#set_tag" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.set_tag(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.set_tag('asdf,asdf')}.to raise_error(ArgumentError)
      end

      it "should add the tag, with its value, to the list of tags to be anonymized" do
        a = Anonymizer.new
        a.set_tag('0040,2008', :value => 'none')
        expect(a.value('0040,2008')).to eql 'none'
      end

      it "should add the tag, using the default empty string as value, when no value is specified for this string type element" do
        a = Anonymizer.new
        a.set_tag('0040,2008')
        expect(a.value('0040,2008')).to eql ''
      end

      it "should add the tag, using 0 as the default value for this integer type element" do
        a = Anonymizer.new
        a.set_tag('0010,21C0')
        expect(a.value('0010,21C0')).to eql 0
      end

      it "should add the tag, using 0.0 as the default value for this float type element" do
        a = Anonymizer.new
        a.set_tag('0010,9431')
        expect(a.value('0010,9431')).to eql 0.0
      end

      it "should update the tag, with the new value, when a pre-existing tag is specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :value => 'KingAnonymous')
        expect(a.value('0010,0010')).to eql 'KingAnonymous'
      end

      it "should update the tag, keeping the old value, when a pre-existing tag is specified but no value given" do
        a = Anonymizer.new
        old_value = a.value('0010,0010')
        a.set_tag('0010,0010')
        expect(a.value('0010,0010')).to eql old_value
      end

      it "should update the enumeration status of the pre-listed tag, when specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :enum => true)
        expect(a.enum('0010,0010')).to be_true
      end

      it "should set the enumeration status for the newly created tag entry, when specified" do
        a = Anonymizer.new
        a.set_tag('0040,2008', :enum => true)
        expect(a.enum('0040,2008')).to be_true
      end

      it "should not change the enumeration status of a tag who's old value is true, when enumeration is not specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :enum => true)
        a.set_tag('0010,0010')
        expect(a.enum('0010,0010')).to be_true
      end

      it "should not change the enumeration status of a tag who's old value is false, when enumeration is not specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :enum => false)
        a.set_tag('0010,0010')
        expect(a.enum('0010,0010')).to be_false
      end

      it "should set the enumeration status for the newly created tag entry as false, when enumeration not specified" do
        a = Anonymizer.new
        a.set_tag('0040,2008')
        expect(a.enum('0040,2008')).to be_false
      end

    end


    describe "#value" do

      it "should raise an ArgumentError when a non-string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value(42)}.to raise_error(ArgumentError)
      end

      it "should raise an ArgumentError when a non-tag string is passed as an argument" do
        a = Anonymizer.new
        expect {a.value('asdf,asdf')}.to raise_error(ArgumentError)
      end

      it "should return the anonymization value to be used for the specified tag" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :value => 'custom_value')
        expect(a.value('0010,0010')).to eql 'custom_value'
      end

    end


    # NB! This method is private.
    describe "#destination" do

      before :each do
        @dcm = DObject.new
        @a = Anonymizer.new
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = '/home/dicom/temp/file.dcm'
        @a.write_path = '/home/dicom/output/'
        expect(@a.send(:destination, @dcm)).to eql '/home/dicom/output/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = '//home/dicom/temp/file.dcm'
        @a.write_path = '//home/dicom/output/'
        expect(@a.send(:destination, @dcm)).to eql '//home/dicom/output/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = 'C:/home/dicom/temp/file.dcm'
        @a.write_path = 'C:/home/dicom/output/'
        expect(@a.send(:destination, @dcm)).to eql 'C:/home/dicom/output/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = '/home/dicom/temp/file.dcm'
        @a.write_path = '/dicom'
        expect(@a.send(:destination, @dcm)).to eql '/dicom/home/dicom/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = '/home/dicom/temp/file.dcm'
        @a.write_path = '/dicom/'
        expect(@a.send(:destination, @dcm)).to eql '/dicom/home/dicom/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = './file.dcm'
        @a.write_path = 'dicom/output/'
        expect(@a.send(:destination, @dcm)).to eql 'dicom/output'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = 'file.dcm'
        @a.write_path = 'dicom/output/'
        expect(@a.send(:destination, @dcm)).to eql 'dicom/output'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = './ruby/file.dcm'
        @a.write_path = 'dicom/output/'
        expect(@a.send(:destination, @dcm)).to eql 'dicom/output/ruby'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = 'ruby/file.dcm'
        @a.write_path = 'dicom/output/'
        expect(@a.send(:destination, @dcm)).to eql 'dicom/output/ruby'
      end

    end

  end

end
