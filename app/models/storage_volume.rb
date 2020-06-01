# frozen_string_literal: true

class StorageVolume
  include ::Loggable

  class << self
    def all
      StoragePool.all.map(&:volumes).flatten
    end

    def find_by(id:)
      pool_id, volume_index = id.split('--', 2)
      volume_index = Integer(volume_index) rescue nil # rubocop:disable Style/RescueModifier
      return if volume_index.nil?

      pool = StoragePool.find_by(id: pool_id)
      return if pool.nil?

      pool.volumes[volume_index]
    end
  end

  attr_reader :volume,
              :pool,
              :hypervisor,
              :type,
              :capacity,
              :allocation,
              :xml,
              :xml_data,
              :name,
              :key,
              :physical,
              :target_path,
              :target_format,
              :id

  def initialize(volume, pool:, id:)
    @volume = volume
    @pool = pool
    @hypervisor = pool.hypervisor
    @id = id
    setup_attributes
  end

  def virtual_machines
    dbg { "finding #{vol_info}, #{pool_info}, #{hv_info}" }

    result = hypervisor.virtual_machines.select do |vm|
      vm.volume_disks.any? do |disk|
        disk.source_pool == pool.name && disk.source_volume == name
      end
    end

    dbg { "found size=#{result.size}, #{vol_info}, #{pool_info}, #{hv_info}" }
    result
  end

  private

  def setup_attributes
    dbg { "setting up vol.id=#{id}, #{pool_info}, #{hv_info}" }

    info = volume.info
    dbg { "info vol.id=#{id}, #{pool_info}, #{hv_info}" }

    @type = info.type
    @capacity = info.capacity
    @allocation = info.allocation

    @xml = volume.xml_desc
    dbg { "xml_desc vol.id=#{id}, #{pool_info}, #{hv_info}" }

    @xml_data = Libvirt::Xml::StorageVolume.load(xml)
    dbg { "xml_data vol.id=#{id}, #{pool_info}, #{hv_info}" }

    @name = xml_data.name
    @key = xml_data.key
    @physical = xml_data.physical
    @target_path = xml_data.target_path
    @target_format = xml_data.target_format

    dbg { "complete #{vol_info}, #{pool_info}, #{hv_info}" }
  end

  def vol_info
    "vol.id=#{id}, vol.name=#{name}, vol.key=#{key}"
  end

  def pool_info
    "pool.uuid=#{pool.uuid}, pool.name=#{pool.name}"
  end

  def hv_info
    "hv.id=#{hypervisor.id}, hv.name=#{hypervisor.name}"
  end
end
