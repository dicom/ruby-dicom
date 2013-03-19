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
        @a.audit_trail.should be_nil
      end

      it "should by default set the audit_trail_file attribute as nil" do
        @a.audit_trail_file.should be_nil
      end

      it "should by default set the blank attribute as false" do
        @a.blank.should be_false
      end

      it "should by default set the delete attribute as an empty hash" do
        @a.delete.should eql Hash.new
      end

      it "should by default set the delete_private attribute as false" do
        @a.delete_private.should be_false
      end

      it "should by default set the encryption attribute as nil" do
        @a.encryption.should be_nil
      end

      it "should by default set the enumeration attribute as false" do
        @a.enumeration.should be_false
      end

      it "should by default set the logger_level attribute as Logger::FATAL" do
        @a.logger_level.should eql Logger::FATAL
      end

      it "should by default set the random_file_name attribute as nil" do
        @a.random_file_name.should be_nil
      end

      it "should by default set the recursive attribute as nil" do
        @a.recursive.should be_nil
      end

      it "should by default set the uid attribute as nil" do
        @a.uid.should be_nil
      end

      it "should by default set the uid_root attribute as the DICOM module's UID_ROOT constant" do
        @a.uid_root.should eql UID_ROOT
      end

      it "should by default set the write_path attribute as nil" do
        @a.write_path.should be_nil
      end

      it "should pass the :audit_trail option to the 'audit_trail_file' attribute" do
        trail_file = 'audit_trail.json'
        a = Anonymizer.new(:audit_trail => trail_file)
        a.audit_trail_file.should eql trail_file
      end

      it "should pass the :blank option to the 'blank' attribute" do
        a = Anonymizer.new(:blank => true)
        a.blank.should be_true
      end

      it "should pass the :delete_private option to the 'delete_private' attribute" do
        a = Anonymizer.new(:delete_private => true)
        a.delete_private.should be_true
      end

      it "should pass the :encryption option to the 'encryption' attribute when a Digest class is passed (along with the :audit_trail option)" do
        require 'digest'
        a = Anonymizer.new(:audit_trail => 'audit_trail.json', :encryption => Digest::SHA256)
        a.encryption.should eql Digest::SHA256
      end

      it "should pass the :enumeration option to the 'enumeration' attribute" do
        a = Anonymizer.new(:enumeration => true)
        a.enumeration.should be_true
      end

      it "should pass the :logger_level option to the 'logger_level' attribute" do
        a = Anonymizer.new(:logger_level => Logger::DEBUG)
        a.logger_level.should eql Logger::DEBUG
      end

      it "should pass the :random_file_name option to the 'random_file_name' attribute" do
        a = Anonymizer.new(:random_file_name => true)
        a.random_file_name.should be_true
      end

      it "should pass the :recursive option to the 'recursive' attribute" do
        a = Anonymizer.new(:recursive => true)
        a.recursive.should be_true
      end

      it "should pass the :uid option to the 'uid' attribute" do
        a = Anonymizer.new(:uid => true)
        a.uid.should be_true
      end

      it "should pass the :uid_root option to the 'uid_root' attribute" do
        custom_uid = '1.999.5'
        a = Anonymizer.new(:uid_root => custom_uid)
        a.uid_root.should eql custom_uid
      end

      it "should pass the :write_path option to the 'write_path' attribute" do
        a = Anonymizer.new(:write_path => true)
        a.write_path.should be_true
      end

      it "should set MD5 as the default Digest class when an :encryption option that is not a Digest class is given (along with the :audit_trail option)" do
        a = Anonymizer.new(:audit_trail => 'audit_trail.json', :encryption => true)
        a.encryption.should eql Digest::MD5
      end

      it "should load an AuditTrail instance to the 'audit_trail' attribute when the :audit_trail option is used" do
        a = Anonymizer.new(:audit_trail => 'audit_trail.json')
        a.audit_trail.should be_an AuditTrail
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
        res.class.should eql Array
        res.length.should eql 0
      end

      it "should return an array with the single DObject instance" do
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        res.class.should eql Array
        res.length.should eql 1
        res[0].object_id.should  eql @dcm1.object_id
      end

      it "should return an array with the two DObject instances" do
        a = Anonymizer.new
        res = a.anonymize([@dcm1, @dcm2])
        res.length.should eql 2
        res[0].object_id.should  eql @dcm1.object_id
        res[1].object_id.should  eql @dcm2.object_id
      end

      it "should replace values selected for anonymization" do
        original = @dcm1.value('0010,0010')
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        adcm = res[0]
        adcm.value('0010,0010').should_not eql original
        adcm.value('0010,0010').should eql a.value('0010,0010')
      end

      it "should not modify values which are not selected for anonymization" do
        original = @dcm1.value('0008,0060')
        a = Anonymizer.new
        res = a.anonymize(@dcm1)
        adcm = res[0]
        adcm.value('0008,0060').should eql original
      end

      it "should anonymize and rewrite the DICOM file (given by its file name string)" do
        file_name = File.join(TMPDIR, "anonymization/example_01/test.dcm")
        @dcm1.write(file_name)
        a = Anonymizer.new
        a.anonymize(file_name)
        dcm1 = DObject.read(file_name)
        dcm1.value('0010,0010').should_not eql @dcm1.value('0010,0010')
        dcm1.value('0010,0010').should eql a.value('0010,0010')
      end

      it "should anonymize and rewrite the DICOM file (given by its directory path string)" do
        file_name = File.join(TMPDIR, "anonymization/example_02/test.dcm")
        @dcm1.write(file_name)
        a = Anonymizer.new
        a.anonymize(File.dirname(file_name))
        dcm1 = DObject.read(file_name)
        dcm1.value('0010,0010').should_not eql @dcm1.value('0010,0010')
        dcm1.value('0010,0010').should eql a.value('0010,0010')
      end

      it "should write the anonymized DICOM file to the separate directory (as given by the :write_path option)" do
        file_name = File.join(TMPDIR, "anonymization/example_03/test.dcm")
        write_path = File.join(TMPDIR, "anonymization/example_03/write")
        @dcm1.write(file_name)
        a = Anonymizer.new(:write_path => write_path)
        a.anonymize(file_name)
        dicom = DICOM.load(write_path)
        original = DObject.read(file_name)
        original.value('0010,0010').should eql @dcm1.value('0010,0010')
        dicom.length.should eql 1
        dicom[0].value('0010,0010').should_not eql @dcm1.value('0010,0010')
      end

      it "should by default keep the original file name when writing an anonymized file to a separate location" do
        file_name = File.join(TMPDIR, "anonymization/example_04/test.dcm")
        write_path = File.join(TMPDIR, "anonymization/example_04/write")
        @dcm1.write(file_name)
        a = Anonymizer.new(:write_path => write_path)
        a.anonymize(file_name)
        File.exists?(File.join(write_path, File.basename(file_name))).should be_true
      end

      it "should use a random file name (but still with a .dcm extension) when the :random_file_name option is used" do
        file_name = File.join(TMPDIR, "anonymization/example_05/test.dcm")
        write_path = File.join(TMPDIR, "anonymization/example_05/write")
        @dcm1.write(file_name)
        a = Anonymizer.new(:random_file_name => true, :write_path => write_path)
        a.anonymize(file_name)
        files = Dir[File.join(write_path, '**/*')]
        files.length.should eql 1
        File.extname(files[0]).should eql '.dcm'
        File.exists?(File.join(write_path, File.basename(file_name))).should be_false
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
        a.delete[tag].should be_false
        a.delete_tag(tag)
        a.delete[tag].should be_true
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
        a.enum('0010,0010').should be_true
        a.set_tag('0010,0010', :enum => false)
        a.enum('0010,0010').should be_false
        a.set_tag('0010,0010', :enum => true)
        a.enum('0010,0010').should be_true
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
        a.value('0010,0010').should be_nil
        a.enum('0010,0010').should be_nil
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
        a.value('0040,2008').should eql 'none'
      end

      it "should add the tag, using the default empty string as value, when no value is specified for this string type element" do
        a = Anonymizer.new
        a.set_tag('0040,2008')
        a.value('0040,2008').should eql ''
      end

      it "should add the tag, using 0 as the default value for this integer type element" do
        a = Anonymizer.new
        a.set_tag('0010,21C0')
        a.value('0010,21C0').should eql 0
      end

      it "should add the tag, using 0.0 as the default value for this float type element" do
        a = Anonymizer.new
        a.set_tag('0010,9431')
        a.value('0010,9431').should eql 0.0
      end

      it "should update the tag, with the new value, when a pre-existing tag is specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :value => 'KingAnonymous')
        a.value('0010,0010').should eql 'KingAnonymous'
      end

      it "should update the tag, keeping the old value, when a pre-existing tag is specified but no value given" do
        a = Anonymizer.new
        old_value = a.value('0010,0010')
        a.set_tag('0010,0010')
        a.value('0010,0010').should eql old_value
      end

      it "should update the enumeration status of the pre-listed tag, when specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :enum => true)
        a.enum('0010,0010').should be_true
      end

      it "should set the enumeration status for the newly created tag entry, when specified" do
        a = Anonymizer.new
        a.set_tag('0040,2008', :enum => true)
        a.enum('0040,2008').should be_true
      end

      it "should not change the enumeration status of a tag who's old value is true, when enumeration is not specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :enum => true)
        a.set_tag('0010,0010')
        a.enum('0010,0010').should be_true
      end

      it "should not change the enumeration status of a tag who's old value is false, when enumeration is not specified" do
        a = Anonymizer.new
        a.set_tag('0010,0010', :enum => false)
        a.set_tag('0010,0010')
        a.enum('0010,0010').should be_false
      end

      it "should set the enumeration status for the newly created tag entry as false, when enumeration not specified" do
        a = Anonymizer.new
        a.set_tag('0040,2008')
        a.enum('0040,2008').should be_false
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
        a.value('0010,0010').should eql 'custom_value'
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
        @a.send(:destination, @dcm).should eql '/home/dicom/output/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = '//home/dicom/temp/file.dcm'
        @a.write_path = '//home/dicom/output/'
        @a.send(:destination, @dcm).should eql '//home/dicom/output/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = 'C:/home/dicom/temp/file.dcm'
        @a.write_path = 'C:/home/dicom/output/'
        @a.send(:destination, @dcm).should eql 'C:/home/dicom/output/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = '/home/dicom/temp/file.dcm'
        @a.write_path = '/dicom'
        @a.send(:destination, @dcm).should eql '/dicom/home/dicom/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = '/home/dicom/temp/file.dcm'
        @a.write_path = '/dicom/'
        @a.send(:destination, @dcm).should eql '/dicom/home/dicom/temp'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = './file.dcm'
        @a.write_path = 'dicom/output/'
        @a.send(:destination, @dcm).should eql 'dicom/output'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = 'file.dcm'
        @a.write_path = 'dicom/output/'
        @a.send(:destination, @dcm).should eql 'dicom/output'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = './ruby/file.dcm'
        @a.write_path = 'dicom/output/'
        @a.send(:destination, @dcm).should eql 'dicom/output/ruby'
      end

      it "should give the expected directory for this file & write_path combination" do
        @dcm.source = 'ruby/file.dcm'
        @a.write_path = 'dicom/output/'
        @a.send(:destination, @dcm).should eql 'dicom/output/ruby'
      end

    end

  end

end
