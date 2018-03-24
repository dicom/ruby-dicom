# encoding: UTF-8

require File.expand_path('../lib/dicom/general/version', __FILE__)

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'dicom'
  s.version = DICOM::VERSION
  s.date = Time.now
  s.summary = "Library for handling DICOM files and DICOM network communication."
  s.require_paths = ['lib']
  s.author = 'Christoffer Lervag'
  s.email = 'chris.lervag@gmail.com'
  s.homepage = 'http://dicom.rubyforge.org/'
  s.license = 'GPL-3.0'
  s.description = "DICOM is a standard widely used throughout the world to store and transfer medical image data. This library enables efficient and powerful handling of DICOM in Ruby, to the benefit of any student or professional who would like to use their favorite language to process DICOM files and communicate across the network."
  s.files = Dir["{lib}/**/*", "[A-Z]*"]
  s.rubyforge_project = 'dicom'

  s.required_ruby_version = '>= 2.2.2'

  s.add_development_dependency('bundler', '~> 1.16')
  s.add_development_dependency('mini_magick', '~> 4.8')
  s.add_development_dependency('mocha', '~> 1.4')
  s.add_development_dependency('numo-narray', '~> 0.9', '>= 0.9.1.1')
  s.add_development_dependency('rake', '~> 12.3')
  s.add_development_dependency('redcarpet', '~> 3.4')
  s.add_development_dependency('rmagick', '~> 2.15')
  s.add_development_dependency('rspec', '~> 3.7')
  s.add_development_dependency('yard', '~> 0.9', '>= 0.9.12')
end