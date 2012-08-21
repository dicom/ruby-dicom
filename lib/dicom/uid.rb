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
    # @param [String] value The UID's value.
    # @param [String] name The UID's name.
    # @param [String] type The UID's type.
    # @param [String] retired The UID's retired status string.
    #
    def initialize(value, name, type, retired)
      @value = value
      @name = name
      @type = type
      @retired = retired
    end

    # Converts the retired status string to a boolean.
    #
    # @return [Boolean] true if the UID is retired, and false if not.
    #
    def retired?
      @retired =~ /R/ ? true : false
    end

    # Checks if the UID is a SOP Class.
    #
    # @return [Boolean] true if the UID is of type SOP Class, and false if not.
    #
    def sop_class?
      @type =~ /SOP Class/ ? true : false
    end

    # Checks if the UID is a Transfer Syntax.
    #
    # @return [Boolean] true if the UID is of type Transfer Syntax, and false if not.
    #
    def transfer_syntax?
      @type =~ /Transfer Syntax/ ? true : false
    end

  end

end