# frozen_string_literal: true

require_relative 'base_resource'

class StoragePoolResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :'storage-pools'

    attributes :state,
               :capacity,
               :allocation,
               :available,
               :xml,
               :name,
               :target_path

    attribute(:pool_type) { @object.type }

    id { @object.uuid }

    has_one :hypervisor do
      linkage always: true

      link(:self) do
        "/api/hypervisors/#{@object.hypervisor.id}"
      end
    end

    has_many :volumes do
      link(:self) do
        "/api/storage-pools/#{@object.uuid}/volumes"
      end
    end

    has_many :'virtual-machines' do
      data { @object.virtual_machines }

      link(:self) do
        "/api/storage-pools/#{@object.uuid}/virtual-machines"
      end
    end

    link(:self) do
      "/api/storage-pools/#{@object.uuid}"
    end
  end

  object_class 'StoragePool'

  class << self
    def top_level_meta(type, _options)
      return unless type == :collection

      not_connected = Hypervisor.all.reject(&:connected?)
      return if not_connected.empty?

      { not_connected_hypervisors: not_connected.map(&:id) }
    end

    def find_collection(_options)
      StoragePool.all
    end

    def find_single(key, _options)
      object = StoragePool.find_by(id: key)
      raise JSONAPI::Errors::NotFound, key if object.nil?

      object
    end
  end
end
