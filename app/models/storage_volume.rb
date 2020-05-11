# frozen_string_literal: true

class StorageVolume
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
    hypervisor.virtual_machines.select do |vm|
      vm.volume_disks.any? do |disk|
        disk.source.pool == pool.name && disk.source.volume == name
      end
    end
  end

  private

  def setup_attributes
    info = volume.info
    @type = info.type
    @capacity = info.capacity
    @allocation = info.allocation

    @xml = volume.xml_desc
    @xml_data = Libvirt::Xml::StorageVolume.load(xml)
    @name = xml_data.name
    @key = xml_data.key
    @physical = xml_data.physical
    @target_path = xml_data.target_path
    @target_format = xml_data.target_format
  end
end
