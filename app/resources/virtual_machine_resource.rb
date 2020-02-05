# frozen_string_literal: true

require_relative 'base_resource'

class VirtualMachineResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :'virtual-machines'

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
      "/api/virtual-machines/#{@object.id}"
    end
  end

  object_class 'VirtualMachine'

  class << self
    def find_collection(options)
      VirtualMachine.all
    end

    def find_single(key, options)
      object = VirtualMachine.find_by(id: key)
      raise JSONAPI::Errors::NotFound, key if object.nil?
      object
    end

    def render_classes
      super.merge HypervisorResource.render_classes
    end

    def update(object, data, _options)
      state = data[:state].to_s.upcase.to_sym
      begin
        object.set_state(state)
      rescue ArgumentError, Libvirt::Error => e
        raise JSONAPI::Errors::ValidationError.new(:state, e.message)
      end
    end
  end
end
