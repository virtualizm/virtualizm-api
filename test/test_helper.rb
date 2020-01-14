# test_helper.rb
ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'minitest/reporters'
require 'active_support/all'

support_paths = File.expand_path 'support/**/*.rb', __dir__
Dir.glob(support_paths).each { |filename| require_relative filename }

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# below this line we load application
StubLibvirt.wrap_application_load do
  require File.expand_path '../app.rb', __dir__
end
