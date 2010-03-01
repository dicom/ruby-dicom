#!/bin/env ruby

# Build command:
# rake package

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'


spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = "dicom"
  s.version = "0.7"
  s.date = Time.now
  s.summary = "Library for handling DICOM files and DICOM network communication."
  s.require_paths = ["lib"]
  s.author = "Christoffer Lervag"
  s.email = "chris.lervag@gmail.com"
  s.homepage = "http://dicom.rubyforge.org/"
  s.rubyforge_project = "dicom"
  s.description = "DICOM is a standard widely used throughout the world to store and transfer medical image data. This project aims to make a library that is able to handle DICOM in the Ruby language, to the benefit of any student or professional who would like to use Ruby to process their DICOM files or communicate across the network."
  s.files = FileList["{lib}/**/*",'[A-Z]*'].to_a
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
    puts "generated latest version"
end

# Genereate the RDoc documentation
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "Dicom library"
  rdoc.options << '--line-numbers' << '--inline-source' << '--main=README'
  rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/*.rb')
  rdoc.rdoc_files.include('lib/dicom/*.rb')
end

desc "Default Task"
task :default => 'test:units'

# Run the unit tests
namespace :test do

  Rake::TestTask.new(:units) do |t|
    t.pattern = 'test/unit/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.verbose = true
  end

  Rake::TestTask.new(:remote) do |t|
    t.pattern = 'test/remote/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.verbose = true
  end

end
