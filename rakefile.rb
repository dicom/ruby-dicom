# Build command:
# rake package

require 'rubygems'
require 'rake/gempackagetask'

spec = eval(File.read('dicom.gemspec'))
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
  pkg.need_tar = true
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
    puts "generated latest version"
end