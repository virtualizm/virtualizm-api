if ENV['RBTRACE']
  require 'rbtrace'
  STDOUT.puts 'RBTrace connected'
end

if ENV['MEMORY_DIAGNOSTIC']
  require 'objspace'
  ObjectSpace.trace_object_allocations_start
  STDOUT.puts "OBJSpace trace started"
end

if ENV['MEMORY_PRINT']
  require 'get_process_mem'
  timeout = ENV['MEMORY_PRINT_TIMEOUT'] || 30
  block = proc do
    mem = GetProcessMem.new
    # rss_bytes = `ps -f -p #{Process.pid} --no-headers -o rss`.to_i * 1024
    STDOUT.puts "MEMORY USAGE #{mem.mb.round(4)} MB"
  end
  block.call
  Async.run_every(timeout, &block)
end

if ENV['GC_TRACE']
  require 'gc_tracer'
  GC::Tracer.start_logging(
      nil,
      gc_stat: false,
      gc_latest_gc_info: false,
      rusage: false,
      #tick_type: :hw_counter,
      events: [
          # :start,
          # :end_mark,
          :end_sweep,
          # :enter,
          # :exit,
          # :newobj,
          # :freeobj
      ]
  )
end

LibvirtAsync.use_logger!(STDOUT)
LibvirtAsync.logger.level = ENV['LIBVIRT_DEBUG'].present? ? :debug : :info
LibvirtAsync.register_implementations!

User.load_storage LibvirtApp.config.users
Hypervisor.load_storage LibvirtApp.config.clusters

LibvirtApp.logger.info "Hypervisors connecting..."
Hypervisor.all.each do |hv|
  LibvirtApp.logger.info "> Hypervisor #{hv.id} #{hv.name} #{hv.uri} connected"
  hv.virtual_machines.each do |vm|
    LibvirtApp.logger.info ">> VM #{vm.id} #{vm.name} retrieved"
  end
end
LibvirtApp.logger.info "OK."

if ScreenshotTimers.enabled?
  ScreenshotTimers.run
end

