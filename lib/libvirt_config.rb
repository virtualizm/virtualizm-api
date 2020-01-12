require 'logger'

class LibvirtConfig < Anyway::Config
  config_name :app # set load path config/app.yml
  attr_config :users,
              :clusters,
              :cookie_secret,
              :cookie_name,
              :libvirt_rw,
              :serve_static,
              :screenshot_timeout,
              logger: ::Logger.new(STDOUT)

  def log_level
    logger.level
  end

  def log_level=(val)
    logger.level = val
  end

  def load!
    raise RuntimeError, "Config #{config_path} does not exist" unless File.file?(config_path)
    # loads config/app.yml
    load
    # validate keys required in config/app.yml
    validate_presence! :users, :clusters, :cookie_secret, :screenshot_timeout
  end

  private

  def validate_presence!(*names)
    names.each do |name|
      raise RuntimeError, "Key #{name} must be present at #{config_path}" if public_send(name).nil?
    end
  end

  def config_path
    @config_path ||= default_config_path(config_name)
  end
end
