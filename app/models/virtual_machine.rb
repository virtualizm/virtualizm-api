# frozen_string_literal: true

require 'tempfile'
require 'securerandom'
# require_relative '../lib/loggable'

class VirtualMachine
  include ::Loggable

  TAGS_URI = 'virtualizm.org/tags'

  attr_reader :domain,
              :hypervisor

  attr_accessor :id,
                :name,
                :cpus,
                :memory,
                :state,
                :xml,
                :tags,
                :xml_data,
                :graphics,
                :disks,
                :is_persistent

  class << self
    def all
      Hypervisor.all.map(&:virtual_machines).flatten
    end

    def find_by(id:)
      all.detect { |domain| domain.id == id }
    end

    # def create(attrs)
    #   factory = DomainFactory.new(memory: attrs[:memory], cpus: attrs[:cpus])
    #   domain  = CLIENT.define_domain_xml(factory.to_xml)
    #   new(domain)
    # end
  end

  def initialize(domain:, hypervisor:)
    @domain = domain
    @hypervisor = hypervisor
    setup_attributes
    sync_state
    sync_persistent
    sync_tags
  end

  def setup_attributes
    dbg { "setting up domain.address=0x#{domain.to_ptr.address.to_s(16)}, #{hv_info}" }

    self.xml = domain.xml_desc
    dbg { "setting up domain.address=0x#{domain.to_ptr.address.to_s(16)}, #{hv_info}" }
    self.xml_data = Libvirt::Xml::Domain.load(xml)
    dbg { "xml_data domain.address=0x#{domain.to_ptr.address.to_s(16)}, #{hv_info}" }
    self.id = xml_data.uuid
    self.name = xml_data.name
    self.cpus = running? ? xml_data.vcpus.count : xml_data.vcpu.value
    self.memory = xml_data.memory.bytes
    self.graphics = xml_data.device_graphics&.map { |g| g.to_h.reject { |_, v| v.nil? } }
    self.disks = xml_data.device_disks&.map { |d| d.to_h.reject { |_, v| v.nil? } }
    dbg { "complete #{vm_info}, domain.address=0x#{domain.to_ptr.address.to_s(16)}, #{hv_info}" }
  end

  def sync_tags
    dbg { "syncing #{vm_info}, #{hv_info}" }

    xml = domain.get_metadata(
        type: :ELEMENT,
        uri: TAGS_URI,
        flags: :AFFECT_CONFIG
    )
    dbg { "get_metadata #{vm_info}, #{hv_info}" }
    @tags = TagsXml.load(xml).tags
    dbg { "parsed #{vm_info}, #{hv_info}" }
  rescue Libvirt::Errors::LibError => _e
    dbg { "failed to get_metadata #{vm_info}, #{hv_info}" }
    @tags = []
  end

  def running?
    state == 'running'
  end

  def sync_state
    dbg { "syncing #{vm_info}, #{hv_info}" }
    self.state = domain.get_state.first.to_s.downcase
    dbg { "get_state #{vm_info}, #{hv_info}" }
  end

  def sync_persistent
    dbg { "syncing #{vm_info}, #{hv_info}" }
    self.is_persistent = domain.persistent?
    dbg { "persistent? #{vm_info}, #{hv_info}" }
  end

  def volume_disks
    xml_data.device_disks.select { |disk| disk.type == 'volume' }
  end

  def storage_volumes
    dbg { "finding #{vm_info}, #{hv_info}" }

    vols = volume_disks.map do |disk|
      disk_pool = hypervisor.storage_pools.detect { |pool| pool.name == disk.source_pool }
      disk_pool.volumes.detect { |volume| volume.name == disk.source_volume }
    end
    dbg { "found size=#{vols.size} #{vm_info}, #{hv_info}" }

    vols
  end

  def storage_pools
    storage_volumes.map(&:pool)
  end

  # @param [String,Symbol]
  # @raise [ArgumentError]
  # @raise [Libvirt::Errors::Error]
  def update_state(state)
    dbg { "updating state=#{state}, #{vm_info}, #{hv_info}" }

    case state.to_s.upcase.to_sym
    when :RUNNING
      domain.start
    when :SHUTDOWN
      domain.shutdown(:ACPI_POWER_BTN)
    when :SHUTOFF
      domain.power_off
    when :SUSPEND
      domain.suspend
    when :RESUME
      domain.resume
    when :REBOOT
      domain.reboot
    when :RESET
      domain.reset
    when :PAUSE
      domain.save_memory
    when :RESTORE
      domain.start
      domain.resume
    else
      raise ArgumentError, "invalid state #{state}"
    end

    dbg { "updated state=#{state} #{vm_info}, #{hv_info}" }
    sync_state
  end

  # @param tags [Array<String>]
  def update_tags(tags)
    dbg { "updating tags=#{tags}, #{vm_info}, #{hv_info}" }

    xml = TagsXml.build(tags).to_xml
    dbg { "build xml tags=#{tags}, #{vm_info}, #{hv_info}" }

    domain.set_metadata(
        xml,
        type: :ELEMENT,
        key: 'virtualizm',
        uri: TAGS_URI,
        flags: :AFFECT_CONFIG
    )

    dbg { "set_metadata tags=#{tags}, #{vm_info}, #{hv_info}" }
    sync_tags
  end

  # Take screenshot asynchronously.
  # @param opaque [Object]
  # @param display [Integer] default 0
  # @yield when stream receive data
  # @yieldparam stream [Libvirt::Stream]
  # @yieldparam events [Integer]
  # @yieldparam opaque [Object]
  # @return [Libvirt::Stream]
  def take_screenshot(opaque, display = 0, &block)
    stream = hypervisor.create_stream
    domain.screenshot(stream, display)
    stream.event_add_callback(
        Libvirt::Stream::EVENT_READABLE,
        opaque,
        &block
    )
    stream
  end

  # @param event_id [Symbol]
  # @param opaque [Object,NilClass]
  # @yieldparam conn [Libvirt::Connection]
  # @yieldparam dom [Libvirt::Domain]
  # @yieldparam *args [Array] specific event arguments
  # @yieldparam opaque [Object,NilClass]
  def register_event_callback(event_id, opaque = nil, &block)
    dbg { "registering #{vm_info}, #{hv_info}" }

    result = hypervisor.register_domain_event_callback(
        event_id,
        domain,
        opaque,
        &block
    )

    dbg { "registered #{vm_info}, #{hv_info}" }
    result
  end

  private

  def vm_info
    "vm.id=#{id}, vm.name=#{name}"
  end

  def hv_info
    "hv.id=#{hypervisor.id}, hv.name=#{hypervisor.name}"
  end

  # def start
  #   domain.create
  # rescue Libvirt::Errors::Error => exception
  #   case exception.libvirt_message
  #   when 'Requested operation is not valid: domain is already running'
  #     return domain
  #   end
  # end
  #
  # def shutdown
  #   domain.shutdown if running?
  # end
  #
  # def halt
  #   domain.destroy if running?
  # end
  #
  # def update
  #   raise NotImplementedError
  # end
  #
  # def destroy
  #   shutdown if running?
  #   domain.undefine
  # end
end
