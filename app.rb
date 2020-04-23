# frozen_string_literal: true

require_relative 'config/environment'

# initialize application
begin
  require_relative 'config/initializer'
rescue StandardError => e
  warn "<#{e.class}>: #{e.message}", e.backtrace
  warn 'Caused by:', "<#{e.cause.class}>: #{e.cause.message}", e.cause.backtrace if e.cause
  Async.schedule_new do
    Process.kill('TERM', Process.pid) # will stop falcon server with exit code 15
  end
end

STDOUT.sync = true
Libvirt.logger = Logger.new(STDOUT)
Libvirt.logger.level = ENV['DEBUG'] ? :debug : :info

# websockets
AsyncCable.config.logger = Libvirt.logger
Application.add_server :events, AsyncCable::Server.new(connection_class: EventCable)

Hypervisor.all.each do |hv|
  hv.on_vm_change do |action, vm|
    case action
    when :create
      EventCable.create_virtual_machine(vm)
    when :update
      EventCable.update_virtual_machine(vm)
    when :destroy
      EventCable.destroy_virtual_machine(vm)
    end
  end
end

# build application server
Application.app = Rack::Builder.new do
  if Application.config.serve_static
    urls = %w[/screenshots]
    static_root = Application.root.join('public')
    Application.logger.info { "Serve static folders [#{urls.join(',')}] from #{static_root}" }
    use Rack::Protection::PathTraversal
    use Rack::Static, urls: urls, root: static_root
  end

  use Rack::XRequestId, logger: Application.logger
  use Rack::MethodOverride

  use Rack::Session::Cookie,
      **Application.config.cookie_params.symbolize_keys,
      key: Application.config.cookie_name,
      secret: Application.config.cookie_secret

  use Rack::ImprovedLogger, Application.logger
  use Rack::Protection::CookieTossing
  use Rack::Protection::IPSpoofing
  use Rack::Protection::SessionHijacking

  use Rack::Router::Middleware, logger: Application.logger do
    not_found :default

    get '/ws_events', ->(env) do
      Application.find_server(:events).call(env)
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
