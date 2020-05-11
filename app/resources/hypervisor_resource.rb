# frozen_string_literal: true

require_relative 'base_resource'

class HypervisorResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :hypervisors

    attributes :name,
               :version,
               :libversion,
               :hostname,
               :max_vcpus,
               :cpu_model,
               :cpus,
               :mhz,
               :numa_nodes,
               :cpu_sockets,
               :cpu_cores,
               :cpu_threads,
               :total_memory,
               :free_memory,
               :capabilities

    attribute(:connected) { @object.connected? }

    has_many :'virtual-machines' do
      data { @object.virtual_machines }

      link(:self) do
        "/api/hypervisors/#{@object.id}/virtual-machines"
      end
    end

    has_many :'storage-pools' do
      data { @object.storage_pools }

      link(:self) do
        "/api/hypervisors/#{@object.id}/storage-pools"
      end
    end

    link(:self) do
      "/api/hypervisors/#{@object.id}"
    end
  end

  object_class 'Hypervisor'

  class << self
    def find_collection(_options)
      Hypervisor.all
    end

    def find_single(key, _options)
      object = Hypervisor.find_by(id: key)
      raise JSONAPI::Errors::NotFound, key if object.nil?

      object
    end
  end
end
