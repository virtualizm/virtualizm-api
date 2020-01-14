require 'active_support/all'
require 'libvirt_async'
require_relative '../../app/models/hypervisor'

module StubLibvirt
  def wrap_application_load
    Hypervisor._storage = []

    LibvirtAsync.stub(:register_implementations!, nil) do
      Hypervisor.stub(:load_storage, nil) do
        yield
      end
    end
  end

  module_function :wrap_application_load
end
