# This script produces DICOM UID and element dictionaries in a specific
# tab separated format which is used by the ruby-dicom library. The source
# of the data is the DICOM Standard, DICOM Part 6: Data Dictionary,
# in the following chapters:
#    6: Registry of DICOM data elements
#    7: Registry of DICOM File Meta Elements
#    8: Registry of DICOM directory structuring elements
#
# Furthermore, the network-related command elements are found in
# DICOM Part 7: Message Exchange, in the following chapters:
#    E.1: Registry of DICOM Command Elements
#    E.2: Retired Command Fields
#
# Steps to run:
# -Locate the Standard version of interest (e.g. http://medical.nema.org/standard.html)
# -Download the Word document version (.doc)
# -Open it in LibreOffice
# -Export it (File => Export), then choose Save as type: XHTML (.html, xhtml)
# -Point this script to the saved XHTML document(s) and execute
# -Copy the produced dictionaries to the appropriate ruby-dicom folder

# Requirements:
require 'nokogiri'

# Settings:
dictionary_file = './11_06pu.html'
message_file = './11_07pu.xhtml'
element_output = 'elements.txt'
uid_output = 'uids.txt'
@@retired = 'R'
@@non_retired = ''
@@vr_not_defined = '  '
@@vr_delimiter = ','
@@delimiter = "\t"

# Load the document:
t1 = Time.now.to_f
dictionary_doc = Nokogiri::HTML(open(dictionary_file))
message_doc = Nokogiri::HTML(open(message_file))

# Extends String class for tag handling.
class String
  def tag?
    if self.length >= 11 && self[1..9] =~ /\A[a-fxA-F\d]{4},[a-fxA-F\d]{4}\z/
      return true
    else
      return false
    end
  end

  def to_tag
    return self[1..9]
  end

  def uid?
    return self =~ /^[0-9]+([\\.]+|[0-9]+)*$/
  end
end

# We use a simple UID class for storing unique identifiers.
class UID
  attr_accessor :name, :type, :part, :ret
  attr_reader :value

  def initialize(value)
    #raise ArgumentError, "Argument #{value} is not a valid UID." unless value.uid?
    @value = value
    @ret = @@non_retired
  end

  # Produces a formatted string from the attributes of the UID instance.
  def output
    return "#{[@value, @name.rstrip, @type, @ret].join(@@delimiter)}\n"
  end
end

# We use a simple Element class for storing the various elements.
class Element
  attr_accessor :tag, :name, :keyword, :vm, :ret
  attr_reader :tag, :vr

  def initialize(tag)
    #raise ArgumentError, "Argument #{tag} is not a valid tag." unless tag.tag?
    @tag = tag
    @ret = @@non_retired
  end

  # Produces a formatted string from the attributes of the Element instance.
  def output
    return "#{[@tag, @name.rstrip, @vr, @vm, @ret].join(@@delimiter)}\n"
  end

  # Sets the VR of the Element.
  def vr=(val)
    if val.include?('or')
      @vr = val.gsub(' or ', @@vr_delimiter)
    else
      @vr = (val == "see note" ? @@vr_not_defined : val)
    end
  end
end

# Use arrays to store all elements and uids:
uids = Array.new
elements = Array.new

# Extract unique identifiers:
nodes = dictionary_doc.search('tr[@class="Table51"]')
nodes[1..-1].each do |node|
  children = node.children
  uid_candidate = children.first.text
  if uid_candidate.uid?
    u = UID.new(uid_candidate)
    u.name = children[1].text
    u.type = children[2].text
    u.part = children[3].text
    u.ret = @@retired if u.name.include?('Retired')
    uids << u
  end
end

# Extract (active) command field elements:
nodes = message_doc.search('tr[@class="Table841"]')
nodes[1..-1].each do |node|
  children = node.children
  tag_candidate = children.first.text
  if tag_candidate.tag?
    e = Element.new(tag_candidate.to_tag)
    e.name = children[1].text
    e.keyword = children[2].text
    e.vr = children[3].text
    e.vm = children[4].text
    elements << e
  end
end

# Extract (retired) command field elements:
nodes = message_doc.search('tr[@class="Table851"]')
nodes[1..-1].each do |node|
  children = node.children
  tag_candidate = children.first.text
  if tag_candidate.tag?
    e = Element.new(tag_candidate.to_tag)
    e.name = children[1].text
    e.keyword = children[2].text
    e.vr = children[3].text
    e.vm = children[4].text
    e.ret = @@retired
    elements << e
  end
end

# Extract elements (file meta, directory structuring & data):
nodes = dictionary_doc.search('tr[@class="Table31"]', 'tr[@class="Table41"]', 'tr[@class="Table11"]', 'tr[@class="Table21"]')
nodes[1..-1].each do |node|
  children = node.children
  tag_candidate = children.first.text
  if tag_candidate.tag?
    e = Element.new(tag_candidate.to_tag)
    e.name = children[1].text
    e.keyword = children[2].text
    e.vr = children[3].text
    e.vm = children[4].text
    e.ret = @@retired if children[5].text == "RET"
    elements << e
  end
end

# Dump the parsed uids to a text file:
File.open(uid_output, 'w') {|f|
  uids.each do |u|
    f.write(u.output)
  end
}

puts "\nUnique identifiers processed and dumped to file!"
puts "#{uids.length} UIDs were found and processed."
puts "For reference: In the DICOM Standard (2011 Edition), there are:"
puts "  334 unique identifiers"

# Dump the parsed elements to a text file:
File.open(element_output, 'w') {|f|
  elements.each do |e|
    f.write(e.output)
  end
}

puts "\nElements processed and dumped to file!"
puts "#{elements.length} tags were found and processed."
puts "For reference: In the DICOM Standard (2011 Edition), there are:"
puts "  3600 file tags (file meta, directory structuring and data elements)"
puts "  46 message tags (command elements)"

puts "\nDictionary processing completed!"
t2 = Time.now.to_f
puts "Time elapsed: #{(t2-t1).round(1)} seconds."