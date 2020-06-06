# frozen_string_literal: true

require_relative 'base_resource'

class InterfaceResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :interfaces

    attributes :is_active,
               :mac,
               :xml,
               :name,
               :bridge,
               :target_dev,
               :model_type

    attribute(:interface_type) { @object.type }

    link(:self) do
      "/api/interfaces/#{@object.id}"
    end
  end

  object_class 'Interface'

  class << self
    def top_level_meta(type, _options)
      return unless type == :collection

      not_connected = Hypervisor.all.reject(&:connected?)
      return if not_connected.empty?

      { not_connected_hypervisors: not_connected.map(&:id) }
    end

    def find_collection(_options)
      Interface.all
    end

    def find_single(key, _options)
      object = Interface.find_by(id: key)
      raise JSONAPI::Errors::NotFound, key if object.nil?

      object
    end
  end
end
