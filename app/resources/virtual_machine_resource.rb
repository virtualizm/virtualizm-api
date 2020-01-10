require_relative 'base_resource'

class VirtualMachineResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :virtual_machines

    attributes :name,
               :state,
               :memory,
               :cpus,
               :xml

    has_one :hypervisor do
      linkage always: true

      link(:self) do
        "/api/hypervisors/#{@object.hypervisor.id}"
      end
    end

    link(:self) do
      "/api/virtual_machines/#{@object.id}"
    end
  end

  object_class 'VirtualMachine'

  class << self
    def find_collection(options)
      VirtualMachine.all
    end

    def find_single(key, options)
      VirtualMachine.find_by(id: key)
    end

    def render_classes
      super.merge HypervisorResource.render_classes
    end
  end
end
