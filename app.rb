# frozen_string_literal: true

require_relative 'config/environment'

# initialize application
begin
  require_relative 'config/initializer'
rescue => e
  STDERR.puts "<#{e.class}>: #{e.message}", e.backtrace
  STDERR.puts 'Caused by:', "<#{e.cause.class}>: #{e.cause.message}", e.cause.backtrace if e.cause
  Async.schedule_new do
    Process.kill('TERM', Process.pid) # will stop falcon server with exit code 15
  end
end

LibvirtApp.add_server :api_cable, AsyncCable::Server.new(connection_class: ApiCable)

# build application server
LibvirtApp.app = Rack::Builder.new do
  if LibvirtApp.config.serve_static
    urls = %w(/screenshots)
    static_root = LibvirtApp.root.join('public')
    LibvirtApp.logger.info { "Serve static folders [#{urls.join(',')}] from #{static_root}" }
    use Rack::Protection::PathTraversal
    use Rack::Static, urls: urls, root: static_root
  end

  use Rack::XRequestId, logger: LibvirtApp.logger
  use Rack::MethodOverride
  use Rack::Session::Cookie, key: LibvirtApp.config.cookie_name, secret: LibvirtApp.config.cookie_secret
  use Rack::ImprovedLogger, LibvirtApp.logger
  use Rack::Protection::CookieTossing
  use Rack::Protection::IPSpoofing
  use Rack::Protection::SessionHijacking

  use Rack::Router::Middleware, logger: LibvirtApp.logger do
    not_found :default

    get '/api_cable', -> (env) do
      LibvirtApp.find_server(:api_cable).call(env)
    end

    namespace :api do
      post '/sessions', [SessionsController, :create]
      get '/sessions', [SessionsController, :show]
      delete '/sessions', [SessionsController, :destroy]

      get '/hypervisors', [HypervisorsController, :index]
      get '/hypervisors/:id', [HypervisorsController, :show]

      get '/virtual-machines', [VirtualMachinesController, :index]
      get '/virtual-machines/:id', [VirtualMachinesController, :show]
      put '/virtual-machines/:id', [VirtualMachinesController, :update]
      patch '/virtual-machines/:id', [VirtualMachinesController, :update]

      get '/spice/:id', [SpiceController, :show]
    end
  end

  run ->(env) do
    route_result = env[Rack::Router::RACK_ROUTER_PATH]
    return route_result.call(env) if route_result.is_a?(Proc)

    controller_class, action = *route_result
    controller_class.call(env, action)
  end
end
