module DICOM
  
  class Parent
    include Logging
    # Deprecated.
    #
    def remove(tag, options={})
      logger.warn("Parent#remove is deprecated. Use #delete instead.")
      delete(tag, options)
    end
    # Deprecated.
    #
    def remove_children
      logger.warn("Parent#remove_children is deprecated. Use #delete_children instead.")
      delete_children
    end

    # Deprecated.
    #
    def remove_group(group_string)
      logger.warn("Parent#remove_group is deprecated. Use #delete_group instead.")
      delete_group(group_string)
    end

    # Deprecated.
    #
    def remove_private
      logger.warn("Parent#remove_private is deprecated. Use #delete_private instead.")
      delete_private
    end
  end
  
  class ImageItem < Parent
    include Logging
    # Deprecated.
    #
    def remove_sequences
      logger.warn("ImageItem#remove_sequences is deprecated. Use #delete_sequences instead.")
      delete_sequences
    end
  end
  
  class DServer
    # Deprecated.
    #
    def remove_abstract_syntax(uid)
      logger.warn("DServer#remove_abstract_syntax is deprecated. Use #delete_abstract_syntax instead.")
      delete_abstract_syntax(uid)
    end

    # Deprecated.
    #
    def remove_transfer_syntax(uid)
      logger.warn("DServer#remove_transfer_syntax is deprecated. Use #delete_transfer_syntax instead.")
      delete_transfer_syntax(uid)
    end

    # Deprecated.
    #
    def remove_all_abstract_syntaxes
      logger.warn("DServer#remove_all_abstract_syntaxes is deprecated. Use #clear_abstract_syntaxes instead.")
      clear_abstract_syntaxes
    end

    # Deprecated.
    #
    def remove_all_transfer_syntaxes
      logger.warn("DServer#remove_all_transfer_syntaxes is deprecated. Use #clear_transfer_syntaxes instead.")
      clear_transfer_syntaxes
    end
  end
  
end