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
    # @param [String] file_name the path to a file containing a previously stored audit trail
    # @return [AuditTrail] the created AuditTrail instance
    #
    def self.read(file_name)
      audit_trail = AuditTrail.new
      audit_trail.load(file_name)
      return audit_trail
    end

    # Creates a new AuditTrail instance.
    #
    def initialize
      # Define the key/value hash used for tag records:
      @dictionary = Hash.new
    end

    # Adds a tag record to the log.
    #
    # @param [String] tag the tag string (e.q. '0010,0010')
    # @param [String, Integer, Float] original the original value (e.q. 'John Doe')
    # @param [String, Integer, Float] replacement the replacement value (e.q. 'Patient1')
    #
    def add_record(tag, original, replacement)
      @dictionary[tag] = Hash.new unless @dictionary.key?(tag)
      @dictionary[tag][original] = replacement
    end

    # Loads the key/value dictionary hash from a specified file.
    #
    # @param [String] file_name the path to a file containing a previously stored audit trail
    #
    def load(file_name)
      @dictionary = JSON.load(File.new(file_name, "r:UTF-8"))
    end

    # Retrieves the original value used for the given combination of tag & replacement value.
    #
    # @param [String] tag the tag string (e.q. '0010,0010')
    # @param [String, Integer, Float] replacement the replacement value (e.q. 'Patient1')
    # @return [String, Integer, Float] the original value of the given tag
    #
    def original(tag, replacement)
      original = nil
      if @dictionary.key?(tag)
        original = @dictionary[tag].key(replacement)
      end
      return original
    end

    # Gives the key/value pairs for a specific tag.
    #
    # @param [String] tag the tag string (e.q. '0010,0010')
    # @return [Hash] the key/value pairs of a specific tag
    #
    def records(tag)
      if @dictionary.key?(tag)
        return @dictionary[tag]
      else
        return Hash.new
      end
    end

    # Retrieves the replacement value used for the given combination of tag & original value.
    #
    # @param [String] tag the tag string (e.q. '0010,0010')
    # @param [String, Integer, Float] original the original value (e.q. 'John Doe')
    # @return [String, Integer, Float] the replacement value of the given tag
    #
    def replacement(tag, original)
      replacement = nil
      replacement = @dictionary[tag][original] if @dictionary.key?(tag)
      return replacement
    end

    # Dumps the key/value pairs to a json string which is written to the specified file.
    #
    # @param [String] file_name the path to be used for storing key/value pairs on disk
    #
    def write(file_name)
      # Encode json string:
      str = JSON.pretty_generate(@dictionary)
      # Create directory if needed:
      unless File.directory?(File.dirname(file_name))
        require 'fileutils'
        FileUtils.mkdir_p(File.dirname(file_name))
      end
      # Write to file:
      File.open(file_name, 'w') {|f| f.write(str) }
    end

  end
end