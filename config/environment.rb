LibvirtApp.setup_config
LibvirtApp.setup_env ENV.fetch('RACK_ENV')
LibvirtApp.setup_root File.expand_path('..', __dir__)

LibvirtApp.configure do |config|
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
  config.log_level = :debug
  config.cookie_name = 'libvirt-app.session'
end

if LibvirtApp.env.development? || LibvirtApp.env.test?
  require 'byebug'
end
