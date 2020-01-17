LibvirtApp.setup_env ENV.fetch('RACK_ENV')
LibvirtApp.setup_root File.expand_path('..', __dir__)

LibvirtApp.setup_config do |config|
  config.logger = ActiveSupport::TaggedLogging.new(
      ::Logger.new(STDOUT, formatter: ::Logger::Formatter.new)
  )
  config.log_level = :debug
  config.cookie_name = 'libvirt-app.session'
end

if LibvirtApp.env.development? || LibvirtApp.env.test?
  begin
    require 'byebug'
  rescue LoadError => e
    STDERR.puts(e.message)
  end
end
