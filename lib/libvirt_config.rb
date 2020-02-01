# frozen_string_literal: true

require 'logger'

class LibvirtConfig < Anyway::Config
  class_attribute :_file_config_keys, instance_writer: false, default: []

  # Define which keys required to be loaded from yml file
  def self.attrs_from_file(*names)
    _file_config_keys.concat(names)
  end

  config_name :app # set load path config/app.yml
  attr_config :users,
              :clusters,
              :cookie_secret,
              :libvirt_rw,
              :serve_static,
              :screenshot_timeout,
              :screenshot_enabled,
              :cookie_name,
              :logger

  attrs_from_file :users,
                  :clusters,
                  :cookie_secret,
                  :libvirt_rw,
                  :serve_static,
                  :screenshot_timeout,
                  :screenshot_enabled

  def log_level
    logger.level
  end

  def log_level=(val)
    logger.level = val
  end

  def setup!
    raise RuntimeError, "Config #{config_path} does not exist" unless File.file?(config_path)
    # loads config/app.yml
    load
    yield(self) if block_given?
    # validate keys required in config/app.yml
    check_attrs_from_file!
  end

  private

  def check_attrs_from_file!
    missing = _file_config_keys.select { |name| public_send(name).nil? }
    unless missing.empty?
      raise RuntimeError, "Key(s) #{missing.join(', ')} must be present at #{config_path}"
    end
  end

  def config_path
    @config_path ||= default_config_path(config_name)
  end
end
