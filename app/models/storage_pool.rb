# frozen_string_literal: true

class StoragePool
  class << self
    def all
      Hypervisor.all.map(&:storage_pools).flatten
    end

    def find_by(id:)
      all.detect { |pool| pool.uuid == id }
    end
  end

  attr_reader :pool,
              :hypervisor,
              :volumes,
              :state,
              :capacity,
              :allocation,
              :available,
              :xml,
              :xml_data,
              :uuid,
              :name,
              :type,
              :target_path

  def initialize(pool, hypervisor:)
    @pool = pool
    @hypervisor = hypervisor
    setup_attributes
  end

  def virtual_machines
    hypervisor.virtual_machines.select do |vm|
      vm.volume_disks.any? { |disk| disk.source_pool == name }
    end
  end

  private

  def setup_attributes
    info = pool.info
    @state = info.state.to_s.downcase
    @capacity = info.capacity
    @allocation = info.allocation
    @available = info.available

    @xml = pool.xml_desc
    @xml_data = Libvirt::Xml::StoragePool.load(xml)
    @uuid = xml_data.uuid
    @name = xml_data.name
    @type = xml_data.type
    @target_path = xml_data.target_path

    # A volume.name is unique per storage pool,
    # but it's not url safe.
    # So we define globally unique id of volume
    # as pool.uuid and volume index in pool array
    @volumes = pool.list_all_volumes.map.with_index do |vol, index|
      id = "#{uuid}--#{index}"
      StorageVolume.new(vol, pool: self, id: id)
    end
  end
end
