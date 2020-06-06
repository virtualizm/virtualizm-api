# frozen_string_literal: true

class Network
  include ::Loggable

  class << self
    def all
      Hypervisor.all.map(&:networks).flatten
    end

    def find_by(id:)
      all.detect { |net| net.uuid == id }
    end
  end

  attr_reader :net,
              :hypervisor,
              :uuid,
              :name,
              :bridge_name,
              :dhcp_leases,
              :xml,
              :xml_data

  attr_accessor :is_active,
                :is_persistent,
                :is_auto_start

  attr_accessor :state, :volumes

  def initialize(net, hypervisor:)
    @net = net
    @hypervisor = hypervisor
    setup_attributes
  end

  private

  def sync_is_active
    self.is_active = net.active?
  end

  def setup_attributes
    dbg { "setting up net.address=0x#{net.to_ptr.address.to_s(16)}, #{hv_info}" }

    @uuid = net.uuid
    @name = net.name
    @bridge_name = net.bridge_name
    @xml = net.xml_desc
    @xml_data = Libvirt::Xml::Network.load(xml)

    self.is_active = net.active?
    self.is_persistent = net.persistent?
    self.is_auto_start = net.auto_start?

    @dhcp_leases = net.dhcp_leases.map { |r| r.to_h.symbolize_keys }

    dbg { "complete #{net_info}, net.address=0x#{net.to_ptr.address.to_s(16)}, #{hv_info}" }
  end

  def hv_info
    "hv.id=#{hypervisor.id}, hv.name=#{hypervisor.name}"
  end

  def net_info
    "net.uuid=#{uuid}, net.name=#{name}"
  end
end
