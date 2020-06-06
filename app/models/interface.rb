# frozen_string_literal: true

class Interface
  include ::Loggable

  class << self
    def all
      Hypervisor.all.map(&:interfaces).flatten
    end

    def find_by(id:)
      all.detect { |iface| iface.id == id }
    end
  end

  attr_reader :iface,
              :hypervisor,
              :id,
              :name,
              :mac,
              :xml,
              :xml_data,
              :type,
              :bridge,
              :target_dev,
              :model_type

  attr_accessor :is_active

  attr_accessor :state, :volumes

  def initialize(iface, hypervisor:)
    @iface = iface
    @hypervisor = hypervisor
    setup_attributes
  end

  private

  def sync_is_active
    self.is_active = iface.active?
  end

  def setup_attributes
    dbg { "setting up iface.address=0x#{iface.to_ptr.address.to_s(16)}, #{hv_info}" }

    @name = iface.name
    @id = NameToId.encode(name)
    @mac = iface.mac
    @xml = iface.xml_desc
    @xml_data = Libvirt::Xml::Interface.load(xml)
    @type = xml_data.type
    @bridge = xml_data.source_bridge
    @target_dev = xml_data.target_dev
    @model_type = xml_data.model_type

    self.is_active = iface.active?

    dbg { "complete #{iface_info}, iface.address=0x#{iface.to_ptr.address.to_s(16)}, #{hv_info}" }
  end

  def hv_info
    "hv.id=#{hypervisor.id}, hv.name=#{hypervisor.name}"
  end

  def iface_info
    "iface.id=#{id}, iface.name=#{name}"
  end
end
