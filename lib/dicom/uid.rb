module DICOM

  # This class handles the various UID types (transfer syntax, SOP Class, LDAP OID, etc)
  # found in the DICOM Data Dictionary (Annex A: Registry of DICOM unique identifiers,
  # Table A-1).
  #
  class UID

    # The UID name, e.g. 'Verification SOP Class'.
    attr_reader :name
    # The UID's retired status string, i.e. an empty string or 'R'.
    attr_reader :retired
    # The UID type, e.g. 'SOP Class'.
    attr_reader :type
    # The UID value, e.g. '1.2.840.10008.1.1'.
    attr_reader :value

    # Creates a new UID.
    #
    # @param [String] value the UID's value
    # @param [String] name the UID's name
    # @param [String] type the UID's type
    # @param [String] retired the UID's retired status string
    #
    def initialize(value, name, type, retired)
      @value = value
      @name = name
      @type = type
      @retired = retired
    end

    # Checks if the UID is a Transfer Syntax that big endian byte order.
    #
    # @return [Boolean] true if the UID indicates big endian byte order, and false if not
    #
    def big_endian?
      @value == EXPLICIT_BIG_ENDIAN ? true : false
    end

    # Checks if the UID is a Transfer Syntax that implies compressed pixel data.
    #
    # @return [Boolean] true if the UID indicates compressed pixel data, and false if not
    #
    def compressed_pixels?
      transfer_syntax? ? (@name =~ /Implicit|Explicit/).nil? : false
    end

    # Checks if the UID is a Transfer Syntax that implies explicit encoding.
    #
    # @return [Boolean] true if the UID indicates explicit encoding, and false if not
    #
    def explicit?
      transfer_syntax? ? (@name =~ /Implicit/).nil? : false
    end

    # Converts the retired status string to a boolean.
    #
    # @return [Boolean] true if the UID is retired, and false if not
    #
    def retired?
      @retired =~ /R/ ? true : false
    end

    # Checks if the UID is a SOP Class.
    #
    # @return [Boolean] true if the UID is of type SOP Class, and false if not
    #
    def sop_class?
      @type =~ /SOP Class/ ? true : false
    end

    # Checks if the UID is a Transfer Syntax.
    #
    # @return [Boolean] true if the UID is of type Transfer Syntax, and false if not
    #
    def transfer_syntax?
      @type =~ /Transfer Syntax/ ? true : false
    end

  end

end