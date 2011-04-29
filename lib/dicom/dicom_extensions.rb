# encoding: UTF-8

## I've put all the extensions I've made to ruby-dicom
## in this file initially. These may be incorporated into
## ruby-dicom when things are more final and properly discussed
## in the community. /John Axel Eriksson, john@insane.se, http://github.com/johnae

module DICOM

  module Elements

    def name_as_method
      LIBRARY.as_method(@name)
    end

  end


  class DataElement

    def inspect
      to_hash.inspect
    end

    def to_hash
      value
    end

    def to_json
      to_hash.to_json
    end

    def to_yaml
      to_hash.to_yaml
    end

  end


  class DObject < SuperItem

    alias_method :read_success?, :read_success
    alias_method :write_success?, :write_success

  end


  class DRead

    def open_file(file)
      ## can now read from any kind of uri using open-uri, limited to http for now though
      if file.index('http')==0
        @retrials = 0
        begin
          @file = open(file, 'rb') # binary encoding (ASCII-8BIT)
        rescue Exception => e
          if @retrials>3
            @retrials = 0
            raise NonExistantFileException.new, '[RubyDicom] File does not exist'
          else
            puts "Warning: Exception in RubyDicom when loading dicom from: #{file}"
            puts "Retrying... #{@retrials}"
            @retrials+=1
            retry
          end
        end
      elsif File.exist?(file)
        if File.readable?(file)
          if not File.directory?(file)
            if File.size(file) > 8
              @file = File.new(file, "rb")
            else
              @msg << "Error! File is too small to contain DICOM information (#{file})."
            end
          else
            @msg << "Error! File is a directory (#{file})."
          end
        else
          @msg << "Error! File exists but I don't have permission to read it (#{file})."
        end
      else
        @msg << "Error! The file you have supplied does not exist (#{file})."
      end
    end

  end


  class SuperParent

    def each(&block)
      children.each_with_index(&block)
    end

    def each_element(&block)
      elements.each_with_index(&block) if children?
    end

    def each_item(&block)
      items.each_with_index(&block) if children?
    end

    def each_sequence(&block)
      sequences.each_with_index(&block) if children?
    end

    def each_tag(&block)
      @tags.each_key(&block)
    end

    def elements
      children.select { |child| child.is_a?(DataElement)}
    end

    def elements?
      elements.any?
    end

    def inspect
      to_hash.inspect
    end

    def items
      children.select { |child| child.is_a?(Item)}
    end

    def items?
      items.any?
    end

    def method_missing(sym, *args, &block)
      tag = LIBRARY.as_tag(sym.to_s) || LIBRARY.as_tag(sym.to_s[0..-2])
      unless tag.nil?
        if sym.to_s[-1..-1] == '?'
          return self.exists?(tag)
        elsif sym.to_s[-1..-1] == '='
          unless args.length==0 || args[0].nil?
            ### MUST FIX! Other elements can also be added
            return self.add DataElement.new(tag, *args)
          else
            return self.remove(tag)
          end
        else
          return self[tag] rescue nil
        end
      end
      super
    end

    def respond_to?(method_name)
      return true unless LIBRARY.as_tag(method_name.to_s).nil?
      return true unless LIBRARY.as_tag(method_name.to_s[0..-2]).nil?
      super
    end

    def sequences
      children.select { |child| child.is_a?(Sequence) }
    end

    def sequences?
      sequences.any?
    end

    # Builds and returns a nested hash containing all children of this parent.
    # Keys are determined by the key_representation attribute, and data element values are used as values.
    #
    # === Notes
    #
    # * For private elements, the tag is used for key instead of the key representation, as private tags lacks names.
    # * For child-less parents, the key_representation attribute is used as value.
    #
    def to_hash
      as_hash = nil
      unless children?
        as_hash = (self.tag.private?) ? self.tag : self.send(DICOM.key_representation)
      else
        as_hash = Hash.new
        children.each do |child|
          if child.tag.private?
            hash_key = child.tag
          elsif child.is_a?(Item)
            hash_key = "Item #{child.index}"
          else
            hash_key = child.send(DICOM.key_representation)
          end
          as_hash[hash_key] = child.to_hash
        end
      end
      return as_hash
    end

    def to_json
      to_hash.to_json
    end

    def to_yaml
      to_hash.to_yaml
    end

  end

end