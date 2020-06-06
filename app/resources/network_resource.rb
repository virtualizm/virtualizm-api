# frozen_string_literal: true

require_relative 'base_resource'

class NetworkResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :networks

    attributes :is_active,
               :bridge_name,
               :xml,
               :name

    id { @object.uuid }

    link(:self) do
      "/api/networks/#{@object.uuid}"
    end
  end

  object_class 'Network'

  class << self
    def top_level_meta(type, _options)
      return unless type == :collection

      not_connected = Hypervisor.all.reject(&:connected?)
      return if not_connected.empty?

      { not_connected_hypervisors: not_connected.map(&:id) }
    end

    def find_collection(_options)
      Network.all
    end

    def find_single(key, _options)
      object = Network.find_by(id: key)
      raise JSONAPI::Errors::NotFound, key if object.nil?

      object
    end
  end
end
