# coding: UTF-8

require File.dirname(__FILE__) + '/../lib/dicom'
Dir[File.expand_path('support/**/*.rb', File.dirname(__FILE__))].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :mocha
  config.color_enabled = true
end