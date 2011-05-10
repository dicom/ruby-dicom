# encoding: UTF-8

require File.expand_path('../lib/dicom/version', __FILE__)

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = "dicom"
  s.version = DICOM::VERSION
  s.date = Time.now
  s.summary = "Library for handling DICOM files and DICOM network communication."
  s.require_paths = ["lib"]
  s.author = "Christoffer Lervag"
  s.email = "chris.lervag@gmail.com"
  s.homepage = "http://dicom.rubyforge.org/"
  s.description = "DICOM is a standard widely used throughout the world to store and transfer medical image data. This library enables efficient and powerful handling of DICOM in Ruby, to the benefit of any student or professional who would like to use their favorite language to process DICOM files and communicate across the network."
  s.files = Dir["{lib}/**/*", "[A-Z]*"]
  s.rubyforge_project = "dicom"

  s.required_ruby_version = ">= 1.8.6"
  s.required_rubygems_version = ">= 1.3.6"

  s.add_development_dependency("bundler", ">= 1.0.0")
  s.add_development_dependency('rspec', '>= 2.5.0')
  s.add_development_dependency('mocha', '>= 0.9.12')
  s.add_development_dependency('narray')
  s.add_development_dependency('rmagick')
  s.add_development_dependency('mini_magick', '>= 3.2.1')
end