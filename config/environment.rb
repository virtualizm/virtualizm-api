# frozen_string_literal: true

require 'bundler'

rack_env = ENV.fetch('RACK_ENV', 'development')
Bundler.require(:default, rack_env)

require 'libvirt/xml'

# load local libs
require_relative '../lib/rack_improved_logger'
require_relative '../lib/rack_x_request_id'
require_relative '../lib/jsonapi/errors'
require_relative '../lib/jsonapi/const'
require_relative '../lib/async_util'

# load application
require_relative '../lib/application'
require_relative '../lib/loggable'

Application.setup_env(rack_env)
Application.setup_root File.expand_path('..', __dir__)

Application.setup_config do |config|
  config.logger = ActiveSupport::TaggedLogging.new(
      ::Logger.new(STDOUT, formatter: ::Logger::Formatter.new)
  )
  config.log_level = :debug
  config.cookie_name = 'libvirt-app.session'
end

# load patches
Dir.glob(Application.root.join('patches/*.rb')).sort.each do |filename|
  require filename
end

# load app files
Dir.glob(Application.root.join('app/**/*.rb')).sort.each do |filename|
  require filename
end
