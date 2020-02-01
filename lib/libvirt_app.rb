# frozen_string_literal: true

require_relative 'libvirt_config'
require_relative 'env_string'

class LibvirtApp
  include Singleton
  extend Forwardable
  extend SingleForwardable

  single_delegate [
                      :app, :app=,
                      :config, :configure,
                      :env, :root, :setup_config, :setup_env, :setup_root,
                      :logger,
                      :find_server, :add_server
                  ] => :instance
  instance_delegate [:logger] => :config

  attr_accessor :app
  attr_reader :root, :config, :env

  def find_server(name)
    @servers&.fetch(name.to_sym, nil)
  end

  def add_server(name, server)
    name = name.to_sym
    @servers ||= {}
    raise ArgumentError, "server #{name} already added" if @servers.key?(name)
    @servers[name] = server
  end

  def setup_config(&block)
    @config = LibvirtConfig.new
    @config.setup!(&block)
  end

  def setup_env(str)
    @env = EnvString.new(str)
  end

  def setup_root(path)
    @root = Pathname.new File.realpath(path.to_s)
  end

  def configure
    yield config
  end
end
