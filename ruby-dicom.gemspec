Gem::Specification.new do |s|
  s.name        = "ruby-dicom"
  s.version     = "0.7.9b"
  s.author      = "Christoffer Lervåg"
  s.email       = "chris.lervag@gmail.com"
  s.homepage    = "http://github.com/cuthbert/ruby-dicom"
  s.summary     = "Dicom for Ruby."
  s.description = "Dicom library for reading/writing dicom files in ruby."

  s.files        = Dir["{lib}/**/*", "[A-Z]*", "init.rb"]
  s.require_path = "lib"

  s.rubyforge_project = s.name
  s.required_rubygems_version = ">= 1.3.4"
end