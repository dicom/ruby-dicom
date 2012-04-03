module DICOM

  # The AuditTrail class handles key/value storage for the Anonymizer.
  # When using the advanced Anonymization options such as enumeration
  # and UID replacement, the AuditTrail class keeps track of key/value
  # pairs and dumps this information to a text file using the json format.
  # This enables us to ensure a unique relationship between the anonymized
  # values and the original values, as well as preserving this relationship
  # for later restoration of original values.
  #
  class AuditTrail

    # The hash used for storing the key/value pairs of this instace.
    attr_reader :dictionary

    # Creates a new AuditTrail instance by loading the information stored
    # in the specified file.
    #
    # === Parameters
    #
    # * <tt>file_name</tt> -- The path to a file containing a previously stored audit trail.
    #
    def self.read(file_name)
      audit_trail = AuditTrail.new
      audit_trail.load(file_name)
      return audit_trail
    end

    # Creates a new AuditTrail instance.
    #
    def initialize
      # The AuditTrail requires JSON for serialization:
      require 'json'
      # Define the key/value hash used for tag records:
      @dictionary = Hash.new
    end

    # Adds a tag record to the log.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- The tag string (e.q. "0010,0010").
    # * <tt>original</tt> -- The original value (e.q. "John Doe").
    # * <tt>replacement</tt> -- The replacement value (e.q. "Patient1").
    #
    def add_record(tag, original, replacement)
      @dictionary[tag] = Hash.new unless @dictionary.key?(tag)
      @dictionary[tag][original] = replacement
    end

    # Loads the key/value dictionary hash from a specified file.
    #
    # === Parameters
    #
    # * <tt>file_name</tt> -- The path to a file containing a previously stored audit trail.
    #
    def load(file_name)
      @dictionary = JSON.load(File.new(file_name, "r"))
    end

    # Retrieves the replacement value used for the given tag and its original value.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- The tag string (e.q. "0010,0010").
    # * <tt>replacement</tt> -- The replacement value (e.q. "Patient1").
    #
    def original(tag, replacement)
      original = nil
      if @dictionary.key?(tag)
        original = @dictionary[tag].key(replacement)
      end
      return original
    end

    # Returns the key/value pairs for a specific tag.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- The tag string (e.q. "0010,0010").
    #
    def records(tag)
      if @dictionary.key?(tag)
        return @dictionary[tag]
      else
        return Hash.new
      end
    end

    # Retrieves the replacement value used for the given tag and its original value.
    #
    # === Parameters
    #
    # * <tt>tag</tt> -- The tag string (e.q. "0010,0010").
    # * <tt>original</tt> -- The original value (e.q. "John Doe").
    #
    def replacement(tag, original)
      replacement = nil
      replacement = @dictionary[tag][original] if @dictionary.key?(tag)
      return replacement
    end

    # Dumps the key/value pairs to a json string which is written to
    # file as specified by the @file_name attribute of this instance.
    #
    #
    # === Parameters
    #
    # * <tt>file_name</tt> -- The file name string to be used for storing & retrieving key/value pairs on disk.
    #
    def write(file_name)
      str = JSON.pretty_generate(@dictionary)
      File.open(file_name, 'w') {|f| f.write(str) }
    end

  end
end