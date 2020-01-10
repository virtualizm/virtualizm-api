require_relative 'libvirt_config'
require_relative 'env_string'

class LibvirtApp
  include Singleton
  extend Forwardable
  extend SingleForwardable

  single_delegate [:app, :app=, :config, :configure, :env, :root, :setup_config, :setup_env, :setup_root, :logger] => :instance
  instance_delegate [:logger] => :config

  attr_accessor :app
  attr_reader :root, :config, :env

  def setup_config
    @config = LibvirtConfig.new
    @config.load!
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
