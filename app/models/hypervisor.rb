# frozen_string_literal: true

class Hypervisor
  include LibvirtAsync::WithDbg

  class_attribute :_storage, instance_accessor: false

  class << self
    def load_storage(clusters)
      dbg { "#{name}.load_storage #{clusters}" }
      self._storage = clusters.map do |cluster|
        Hypervisor.new(**cluster.symbolize_keys)
      end
      dbg { "#{name}.load_storage loaded size=#{_storage.size}" }
    end

    def all
      dbg { "#{name}.all" }
      result = _storage
      dbg { "#{name}.all found size=#{result.size}" }
      result
    end

    def find_by(id:)
      dbg { "#{name}.find_by id=#{id}" }
      result = _storage.detect { |hv| hv.id.to_s == id.to_s }
      dbg { "#{name}.find_by found id=#{result&.id}, name=#{result&.name}, uri=#{result&.uri}" }
      result
    end
  end

  attr_reader :id,
              :name,
              :uri,
              :ws_endpoint,
              :virtual_machines,
              :connection

  attr_accessor :version,
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

  def initialize(id:, name:, uri:, ws_endpoint:)
    dbg { "#{self.class}#initialize id=#{id}, name=#{name}, uri=#{uri}" }

    @id = id
    @name = name
    @uri = uri
    @ws_endpoint = ws_endpoint
    @dom_cb_ids = []
    @running = nil
    @on_close = []
    @on_open = []

    #force connect to initialize events callbacks
    set_connection
    try_connect
  end

  def to_json(_opts = nil)
    as_json.to_json
  end

  def as_json
    {
        id: @id,
        name: @name
    }
  end

  def on_domain_event(event_id, domain = nil, opaque = nil, &block)
    callback_id = connection.register_domain_event_callback(
        event_id,
        domain,
        opaque,
        &block
    )
    @dom_cb_ids.push(callback_id)
    callback_id
  end

  def deregister_all_domain_events
    @dom_cb_ids.each do |callback_id|
      connection.deregister_domain_event_callback(callback_id)
      @dom_cb_ids.delete(callback_id)
    end
    true
  end

  def running?
    @running
  end

  def on_close(&block)
    @on_close.push(block)
  end

  def on_open(&block)
    @on_open.push(block)
  end

  private

  def set_connection
    dbg { "#{self.class}#_open_connection Opening RW connection to name=#{name} id=#{id}, uri=#{uri}" }
    @connection = Libvirt::Connection.new(uri)
    _open_connection
  end

  def try_connect
    _open_connection
    if running?
      LibvirtApp.logger.info { "Hypervisor##{id} connected." }
      setup_attributes
      register_dom_event_callbacks
      register_close_callback
      load_virtual_machines
      @on_open.each { |cb| cb.call(self) }
    else
      LibvirtApp.logger.info { "Hypervisor##{id} connect failed. Retry is scheduled." }
      schedule_try_connect
    end
  end

  def schedule_try_connect
    Async.run_after(LibvirtApp.config.reconnect_timeout) do
      try_connect
    end
  end

  def register_close_callback
    connection.register_close_callback { |_c, reason, _op| when_closed(reason) }
  end

  def when_closed(reason)
    LibvirtApp.logger.info { "Hypervisor##{id} connection was closed (#{reason}). Retry is scheduled." }
    @on_close.each { |cb| cb.call(self) }
    @virtual_machines = []
    try_connect
  end

  def load_virtual_machines
    dbg { "#{self.class}#load_virtual_machines id=#{id}, name=#{name}, uri=#{uri}" }
    @virtual_machines = connection.list_all_domains.map { |vm| VirtualMachine.new(domain: vm, hypervisor: self) }
    dbg { "#{self.class}#load_virtual_machines loaded size=#{virtual_machines.size} id=#{id}, name=#{name}, uri=#{uri}" }
  end

  def _open_connection
    connection.open
    # c.set_keep_alive(10, 2)
    dbg { "#{self.class}#_open_connection Connected name=#{name} id=#{id}, uri=#{uri}" }
    @running = true
  rescue Libvirt::Error => e
    dbg { "#{self.class}#_open_connection Failed #{e.message} name=#{name} id=#{id}, uri=#{uri}" }
    @running = false
  end

  def setup_attributes
    self.version = connection.version
    self.libversion = connection.lib_version
    self.hostname = connection.hostname
    self.max_vcpus = connection.max_vcpus
    self.capabilities = connection.capabilities

    node_info = connection.node_info
    self.cpu_model = node_info.model
    self.cpus = node_info.cpus
    self.mhz = node_info.mhz
    self.numa_nodes = node_info.nodes
    self.cpu_sockets = node_info.sockets
    self.cpu_cores = node_info.cores
    self.cpu_threads = node_info.threads
    self.total_memory = node_info.memory
    self.free_memory = node_info.memory
  end

  def register_dom_event_callbacks
    on_domain_event(
        :REBOOT,
        &method(:dom_event_callback_reboot)
    )

    on_domain_event(
        :LIFECYCLE,
        &method(:dom_event_callback_lifecycle)
    )

    on_domain_event(
        :RTC_CHANGE,
        &method(:dom_event_callback_rtc_change)
    )

    on_domain_event(
        :WATCHDOG,
        &method(:dom_event_callback_watchdog)
    )

    on_domain_event(
        :IO_ERROR,
        &method(:dom_event_callback_io_error)
    )

    on_domain_event(
        :IO_ERROR_REASON,
        &method(:dom_event_callback_io_error_reason)
    )

    on_domain_event(
        :GRAPHICS,
        &method(:dom_event_callback_graphics)
    )
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_REBOOT
  def dom_event_callback_reboot(_conn, dom, _opaque)
    LibvirtApp.logger.debug { "DOMAIN EVENT REBOOT hv.id=#{id}, vm.id=#{dom.uuid}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE
  def dom_event_callback_lifecycle(_conn, dom, event, detail, _opaque)
    LibvirtApp.logger.debug { "DOMAIN EVENT LIFECYCLE hv.id=#{id}, vm.id=#{dom.uuid}, event=#{event}, detail=#{detail}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_RTC_CHANGE
  def dom_event_callback_rtc_change(_conn, dom, utc_offset, _opaque)
    LibvirtApp.logger.debug { "DOMAIN EVENT RTC_CHANGE hv.id=#{id}, vm.id=#{dom.uuid}, utc_offset=#{utc_offset}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_WATCHDOG
  def dom_event_callback_watchdog(_conn, dom, action, _opaque)
    LibvirtApp.logger.debug { "DOMAIN EVENT WATCHDOG hv.id=#{id}, vm.id=#{dom.uuid}, action=#{action}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_IO_ERROR
  def dom_event_callback_io_error(_conn, dom, src_path, dev_alias, action, _opaque)
    LibvirtApp.logger.debug { "DOMAIN EVENT IO_ERROR hv.id=#{id}, vm.id=#{dom.uuid}, src_path=#{src_path}, dev_alias=#{dev_alias}, action=#{action}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_IO_ERROR_REASON
  def dom_event_callback_io_error_reason(_conn, dom, src_path, dev_alias, action, _opaque)
    LibvirtApp.logger.debug { "DOMAIN EVENT IO_ERROR_REASON hv.id=#{id}, vm.id=#{dom.uuid}, src_path=#{src_path}, dev_alias=#{dev_alias}, action=#{action}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_GRAPHICS
  def dom_event_callback_graphics(_conn, dom, phase, local, remote, auth_scheme, subject, _opaque)
    LibvirtApp.logger.debug { "DOMAIN EVENT GRAPHICS hv.id=#{id}, vm.id=#{dom.uuid}, phase=#{phase}, local=#{local}, remote=#{remote}, auth_scheme=#{auth_scheme}, subject=#{subject}" }
  end
end
