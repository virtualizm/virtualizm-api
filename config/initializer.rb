LibvirtAsync.use_logger!(STDOUT)
LibvirtAsync.logger.level = ENV['LIBVIRT_DEBUG'].present? ? :debug : :info
LibvirtAsync.register_implementations!

User.load_storage LibvirtApp.config.users
Hypervisor.load_storage LibvirtApp.config.clusters

Hypervisor.all.each do |hv|
  puts "> Hypervisor #{hv.id} #{hv.name} #{hv.uri}"
  hv.virtual_machines.each do |vm|
    puts ">> VM #{vm.id} #{vm.name}"
  end
end
