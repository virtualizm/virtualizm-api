require 'active_support/all'
require 'libvirt_async'
require_relative '../../app/models/hypervisor'

module StubLibvirt
  def wrap_application_load

    vm_stub = Minitest::Mock.new
    vm_stub.expect :id, 'id'
    vm_stub.expect :name, 'name'

    hv_stub = Minitest::Mock.new
    hv_stub.expect :id, 'id'
    hv_stub.expect :name, 'name'
    hv_stub.expect :uri, 'uri'
    hv_stub.expect :virtual_machines, [vm_stub]

    LibvirtAsync.stub :register_implementations!, nil do
      Hypervisor.stub :new, hv_stub do
        yield
      end
    end
  end

  module_function :wrap_application_load
end
