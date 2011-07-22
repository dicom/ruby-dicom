#!/usr/bin/ruby
require 'dicom'
require 'optparse'

options = {}
 
optparse = OptionParser.new do|opts|
  opts.banner = "Usage anon.rb [options] <read folder> <write folder>"
  # Define the options, and what they do
  options[:study] = false
  opts.on( '-s', '--study', 'Anonymize Study UIDs' ) do
    options[:study] = true
  end

  options[:identity] = nil
  opts.on( '-i', '--identity FILE', 'Create an identity file' ) do|file|
    options[:identity] = file
  end
  
  options[:db] = false
  opts.on('-d','--db', 'Use sqlite db to store identity info. Looks for identity.db in pwd') do 
    options[:db] = true
  end
  
  options[:root] = false
  opts.on('-r','--dicomroot ROOT', 'Enter your organization\'s DICOM org root. Used for study uid anonymization') do |root|
    options[:root] = root
  end

  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
  
end

optparse.parse!

if ARGV.length != 2
  puts "No destination folder specified, will write over originals."
  options[:folder] = ARGV[0]
else
  options[:folder] = ARGV[0]
  options[:write] = ARGV[1]
end

# Load an anonymization instance:
a = DICOM::Anonymizer.new(options)
# Add the folder to be anonymized:
a.add_folder(options[:folder])
# Request private data element removal:
a.remove_private = true
# Anonymize study uid?
if options[:study]
  a.set_tag("0020,000D", :value => "studyuid", :enum => true) 
end
# Select the enumeration feature:
a.enumeration = true
# Specify a file to keep track of the identities behind the enumerated, anonymized values:
if options[:identity] != nil
  a.identity_file = options[:identity]
end

# Avoid changing the original files by storing the anonymized files in a separate folder from the original files:
if options[:write] != nil
  a.write_path = options[:write]
end

# Print the list of selected tags just to verify that everything is correct:
a.print
# Run the actual anonymization:
a.execute
