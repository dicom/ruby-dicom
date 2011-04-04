# For developers:

# Required gems:
#   gem install rake
# For specs/testing:
#   gem install rspec
#   gem install mocha

# Rake commands:
# Packaging a new gem:
#   rake package
# Test the specification:
#   rake spec

require 'rubygems'
require 'rake/gempackagetask'
require 'rspec/core/rake_task'

# Build gem:
gem_spec = eval(File.read('dicom.gemspec'))
Rake::GemPackageTask.new(gem_spec) do |pkg|
  pkg.gem_spec = gem_spec
  pkg.need_tar = true
end

# RSpec 2:
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = ["-c", "-f progress", "-r ./spec/spec_helper.rb"]
  t.pattern = 'spec/**/*_spec.rb'
end