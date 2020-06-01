# frozen_string_literal: true

class StoragePool
  include ::Loggable

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
              :capacity,
              :allocation,
              :available,
              :xml,
              :xml_data,
              :uuid,
              :name,
              :type,
              :target_path

  attr_accessor :state, :volumes

  def initialize(pool, hypervisor:)
    @pool = pool
    @hypervisor = hypervisor
    setup_attributes
    sync_state
  end

  def virtual_machines
    dbg { "finding #{pool_info}, #{hv_info}" }

    result = hypervisor.virtual_machines.select do |vm|
      vm.volume_disks.any? { |disk| disk.source_pool == name }
    end

    dbg { "found size=#{result.size}, #{pool_info}, #{hv_info}" }
    result
  end

  def sync_state
    dbg { "syncing #{pool_info}, #{hv_info}" }
    self.state = pool.info.state.to_s.downcase
    dbg { "synced state=#{state}, #{pool_info}, #{hv_info}" }

    # If pool is not running we can't retrieve it's volumes.
    self.volumes = running? ? retrieve_volumes : []
  end

  def running?
    state == 'running'
  end

  private

  def setup_attributes
    dbg { "setting up pool.address=0x#{pool.to_ptr.address.to_s(16)}, #{hv_info}" }

    info = pool.info
    dbg { "pool info pool.address=0x#{pool.to_ptr.address.to_s(16)}, #{hv_info}" }
    @capacity = info.capacity
    @allocation = info.allocation
    @available = info.available

    @xml = pool.xml_desc
    dbg { "xml_desc pool.address=0x#{pool.to_ptr.address.to_s(16)}, #{hv_info}" }
    @xml_data = Libvirt::Xml::StoragePool.load(xml)
    dbg { "xml_data pool.address=0x#{pool.to_ptr.address.to_s(16)}, #{hv_info}" }
    @uuid = xml_data.uuid
    @name = xml_data.name
    @type = xml_data.type
    @target_path = xml_data.target_path

    dbg { "complete #{pool_info}, pool.address=0x#{pool.to_ptr.address.to_s(16)}, #{hv_info}" }
  end

  # A volume.name is unique per storage pool,
  # but it's not url safe.
  # So we define globally unique id of volume
  # as pool.uuid and volume index in pool array
  def retrieve_volumes
    dbg { "retrieving #{pool_info}, #{hv_info}" }

    volumes = pool.list_all_volumes
    dbg { "list_all_volumes #{pool_info}, #{hv_info}" }

    storage_volumes = volumes.map.with_index do |vol, index|
      id = "#{uuid}--#{index}"
      StorageVolume.new(vol, pool: self, id: id)
    end

    dbg { "retrieved size=#{storage_volumes.size}, #{pool_info}, #{hv_info}" }
    storage_volumes
  end

  def hv_info
    "hv.id=#{hypervisor.id}, hv.name=#{hypervisor.name}"
  end

  def pool_info
    "pool.uuid=#{uuid}, pool.name=#{name}"
  end
end
