# Build command:
# rake package

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'

spec = eval(File.read('dicom.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
  pkg.need_tar = true
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

end