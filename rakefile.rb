# For developers:

# Required gems:
#   gem install rake
# For specs/testing:
#   gem install rspec
#   gem install mocha

# Rake commands:
# Packaging a new gem:
#   rake package
# Running specs/tests:
#   rake spec
#   rake tests

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rspec/core/rake_task'

spec = eval(File.read('dicom.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
  pkg.need_tar = true
end

desc "Run all unit tests"
task :tests => 'test:units'

# Run the unit tests
namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.pattern = 'test/unit/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.verbose = true
  end
end

# RSpec 2.x
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = ["-c", "-f progress", "-r ./spec/spec_helper.rb"]
  t.pattern = 'spec/**/*_spec.rb'
end