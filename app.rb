require 'active_support/all'
require 'rack/protection'
require 'rack/router'
require 'async_cable'
require 'libvirt'
require 'libvirt_async'
require 'jsonapi/serializable'
require 'jsonapi/deserializable'

# load local libs and patches
require_relative 'lib/rack_improved_logger'
require_relative 'lib/rack_x_request_id'
require_relative 'lib/jsonapi/errors'
require_relative 'lib/jsonapi/const'
require_relative 'patches/falcon'

# load application
require_relative 'lib/libvirt_app'
require_relative 'config/environment'

Dir.glob('app/**/*.rb').sort.each { |filename| require_relative filename }

# initialize application
require_relative 'config/initializer'

# build application server
LibvirtApp.app = Rack::Builder.new do
  use Rack::XRequestId, logger: LibvirtApp.logger
  use Rack::MethodOverride
  use Rack::Session::Cookie, key: LibvirtApp.config.cookie_name, secret: LibvirtApp.config.cookie_secret
  use Rack::ImprovedLogger, LibvirtApp.logger
  use Rack::Protection, use: [:cookie_tossing, :content_security_policy, :remote_referrer, :strict_transport]
  # use Rack::Static, urls: %w(/assets /index.html), root: File.join(__dir__, 'public')

  use Rack::Router::Middleware, logger: LibvirtApp.logger do
    not_found :default

    namespace :api do
      post '/sessions', [SessionsController, :create]
      get '/sessions', [SessionsController, :show]
      delete '/sessions', [SessionsController, :destroy]

      get '/hypervisors', [HypervisorsController, :index]
      get '/hypervisors/:id', [HypervisorsController, :show]

      get '/virtual-machines', [VirtualMachinesController, :index]
      get '/virtual-machines/:id', [VirtualMachinesController, :show]
    end
  end

  run ->(env) do
    path = env[Rack::Router::RACK_ROUTER_PATH]
    return path.call(env) if path.is_a?(Proc)

    controller_class, action = *path
    controller_class.call(env, action)
  end
end
