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

LibvirtApp.logger.info "VM screenshot save starting..."
VirtualMachine.all.each do |vm|
  if vm.running?
    ScreenshotTimers.add(vm)
    LibvirtApp.logger.info "> VM #{vm.id} state is #{vm.state} so started"
  else
    LibvirtApp.logger.info "> VM #{vm.id} state is #{vm.state} so skipping"
  end
end
LibvirtApp.logger.info "OK."
