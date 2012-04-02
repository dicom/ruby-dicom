require 'json'
module DICOM
    class AuditTrail

        def initialize(filename="audittrail.json")
            @filename = filename
            
            audittrail = nil
            audittrail = File.new(@filename, "r") if File.exists?(@filename)

            # if the file is not empty, load the JSON, if not, just create an empty hash
            if audittrail and audittrail.size > 0
                @dictionary = JSON.load(audittrail)
            else
                @dictionary = Hash.new
            end

            audittrail.close if audittrail
        end
        
        def add_tag_record(tagname, original, clean, date=nil)
            lowercase = tagname.downcase
            @dictionary[lowercase] = Hash.new if not @dictionary.has_key?(lowercase)
            @dictionary[lowercase][original] = clean
        end

        def get_clean_tag(tagname, original)
            lowercase = tagname.downcase
            if @dictionary.has_key?(lowercase) and @dictionary[lowercase].has_key?(original)
                return @dictionary[lowercase][original]
            else 
                return nil
            end
        end
        
        def serialize
            audittrail = File.new(@filename, "w")
            JSON.dump(@dictionary, anIO=audittrail)
            audittrail.close
        end

        def previous_values(tagname)
            lowercase = tagname.downcase
            return 0 if not @dictionary.has_key?(lowercase)
            return @dictionary[lowercase].size
        end
    end
end