require 'bundler'

rack_env = ENV.fetch('RACK_ENV', 'development')
Bundler.require(:default, rack_env)

# load local libs
require_relative '../lib/rack_improved_logger'
require_relative '../lib/rack_x_request_id'
require_relative '../lib/jsonapi/errors'
require_relative '../lib/jsonapi/const'
require_relative '../lib/async_util'

# load application
require_relative '../lib/libvirt_app'

LibvirtApp.setup_env(rack_env)
LibvirtApp.setup_root File.expand_path('..', __dir__)

LibvirtApp.setup_config do |config|
  config.logger = ActiveSupport::TaggedLogging.new(
      ::Logger.new(STDOUT, formatter: ::Logger::Formatter.new)
  )
  config.log_level = :debug
  config.cookie_name = 'libvirt-app.session'
end

# load patches
Dir.glob(LibvirtApp.root.join('patches/*.rb')).sort.each do |filename|
  require filename
end

# load app files
Dir.glob(LibvirtApp.root.join('app/**/*.rb')).sort.each do |filename|
  require filename
end
