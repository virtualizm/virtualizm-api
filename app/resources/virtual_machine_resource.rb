# frozen_string_literal: true

require_relative 'base_resource'

class VirtualMachineResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :'virtual-machines'

    attributes :name,
               :state,
               :memory,
               :cpus,
               :xml,
               :tags,
               :graphics,
               :disks,
               :is_persistent,
               :auto_start

    has_one :hypervisor do
      linkage always: true

      link(:self) do
        "/api/hypervisors/#{@object.hypervisor.id}"
      end
    end

    has_many :'storage-pools' do
      data { @object.storage_pools }

      link(:self) do
        "/api/virtual-machines/#{@object.id}/storage-pools"
      end
    end

    has_many :'storage-volumes' do
      data { @object.storage_volumes }

      link(:self) do
        "/api/virtual-machines/#{@object.id}/storage-volumes"
      end
    end

    link(:self) do
      "/api/virtual-machines/#{@object.id}"
    end
  end

  object_class 'VirtualMachine'

  class << self
    def top_level_meta(type, _options)
      return unless type == :collection

      not_connected = Hypervisor.all.reject(&:connected?)
      return if not_connected.empty?

      { not_connected_hypervisors: not_connected.map(&:id) }
    end

    def find_collection(_options)
      VirtualMachine.all
    end

    def find_single(key, _options)
      object = VirtualMachine.find_by(id: key)
      raise JSONAPI::Errors::NotFound, key if object.nil?

      object
    end

    def update(object, attrs, _options)
      object.update_state attrs[:state] if attrs.key?(:state)
      object.update_tags attrs[:tags] if attrs.key?(:tags)
      object.update_auto_start attrs[:auto_start] if attrs.key?(:auto_start)
    rescue ArgumentError, Libvirt::Errors::Error => e
      raise JSONAPI::Errors::ValidationError.new(:state, e.message)
    end
  end
end
