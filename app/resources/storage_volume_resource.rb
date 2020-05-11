# frozen_string_literal: true

require_relative 'base_resource'

class StorageVolumeResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :'storage-volumes'

    attributes

    has_one :pool do
      linkage always: true

      link(:self) do
        "/api/storage-volumes/#{@object.pool.uuid}"
      end
    end

    has_one :hypervisor do
      linkage always: true

      link(:self) do
        "/api/hypervisors/#{@object.hypervisor.id}"
      end
    end

    has_many :'virtual-machines' do
      data { @object.virtual_machines }

      link(:self) do
        "/api/storage-volumes/#{@object.id}/virtual-machines"
      end
    end

    link(:self) do
      "/api/storage-volumes/#{@object.id}"
    end
  end

  object_class 'StorageVolume'

  class << self
    def top_level_meta(type, _options)
      return unless type == :collection

      not_connected = Hypervisor.all.reject(&:connected?)
      return if not_connected.empty?

      { not_connected_hypervisors: not_connected.map(&:id) }
    end

    def find_collection(_options)
      StorageVolume.all
    end

    def find_single(key, _options)
      object = StorageVolume.find_by(id: key)
      raise JSONAPI::Errors::NotFound, key if object.nil?

      object
    end
  end
end
