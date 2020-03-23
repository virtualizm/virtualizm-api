# frozen_string_literal: true

require 'tempfile'
require 'securerandom'

class VirtualMachine
  include LibvirtAsync::WithDbg

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
                :disks

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
    sync_tags
  end

  def setup_attributes
    self.xml = domain.xml_desc
    self.xml_data = Libvirt::Xml::Domain.load(xml)
    self.id = xml_data.uuid
    self.name = xml_data.name
    self.cpus = running? ? xml_data.vcpus.count : xml_data.vcpu.value
    self.memory = xml_data.memory.bytes
    self.graphics = xml_data.device_graphics&.map { |g| g.to_h.reject { |_, v| v.nil? } }
    self.disks = xml_data.device_disks&.map { |d| d.to_h.reject { |_, v| v.nil? } }
  end

  def sync_tags
    xml = domain.get_metadata(
        type: :ELEMENT,
        uri: TAGS_URI,
        flags: :AFFECT_CONFIG
    )
    @tags = TagsXml.load(xml).tags
  rescue Libvirt::Errors::LibError => _e
    @tags = []
  end

  def running?
    state == 'running'
  end

  def sync_state
    self.state = domain.get_state.first.to_s.downcase
  end

  # @param [String,Symbol]
  # @raise [ArgumentError]
  # @raise [Libvirt::Errors::Error]
  def update_state(state)
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

    sync_state
  end

  # @param tags [Array<String>]
  def update_tags(tags)
    xml = TagsXml.build(tags).to_xml
    domain.set_metadata(
        xml,
        type: :ELEMENT,
        key: 'virtualizm',
        uri: TAGS_URI,
        flags: :AFFECT_CONFIG
    )

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
    hypervisor.register_domain_event_callback(
        event_id,
        domain,
        opaque,
        &block
    )
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
