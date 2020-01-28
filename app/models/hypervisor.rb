class Hypervisor
  include LibvirtAsync::WithDbg

  class_attribute :_storage, instance_accessor: false

  class << self
    def load_storage(clusters)
      dbg { "#{name}.load_storage #{clusters}" }
      self._storage = clusters.map do |cluster|
        Hypervisor.new(id: cluster['id'], name: cluster['name'], uri: cluster['uri'])
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
              :virtual_machines

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

  def initialize(id:, name:, uri:)
    dbg { "#{self.class}#initialize id=#{id}, name=#{name}, uri=#{uri}" }

    @id = id
    @name = name
    @uri = uri

    #force connect to initialize events callbacks
    connection
    setup_attributes
    register_dom_event_callbacks
    load_virtual_machines
  end

  def connection
    @connection ||= _open_connection
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

  private

  def load_virtual_machines
    dbg { "#{self.class}#load_virtual_machines id=#{id}, name=#{name}, uri=#{uri}" }
    @virtual_machines = connection.list_all_domains.map { |vm| VirtualMachine.new(domain: vm, hypervisor: self) }
    dbg { "#{self.class}#load_virtual_machines loaded size=#{virtual_machines.size} id=#{id}, name=#{name}, uri=#{uri}" }
  end

  def _open_connection
    dbg { "#{self.class}#_open_connection Opening RW connection to name=#{name} id=#{id}, uri=#{uri}" }
    c = Libvirt::Connection.new(uri)
    c.open

    dbg { "#{self.class}#_open_connection Connected name=#{name} id=#{id}, uri=#{uri}" }

    # c.set_keep_alive(10, 2)
    c
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
    # connection.domain_event_register_any(
    #     Libvirt::Connect::DOMAIN_EVENT_ID_REBOOT,
    #     method(:dom_event_callback_reboot).to_proc
    # )

    connection.register_domain_event_callback(
        Libvirt::DOMAIN_EVENT_ID_LIFECYCLE,
        &method(:dom_event_callback_lifecycle)
    )

    # connection.domain_event_register_any(
    #     Libvirt::Connect::DOMAIN_EVENT_ID_RTC_CHANGE,
    #     method(:dom_event_callback_rtc_change).to_proc
    # )
    #
    # connection.domain_event_register_any(
    #     Libvirt::Connect::DOMAIN_EVENT_ID_WATCHDOG,
    #     method(:dom_event_callback_watchdog).to_proc
    # )
    #
    # connection.domain_event_register_any(
    #     Libvirt::Connect::DOMAIN_EVENT_ID_IO_ERROR,
    #     method(:dom_event_callback_io_error).to_proc
    # )
    #
    # connection.domain_event_register_any(
    #     Libvirt::Connect::DOMAIN_EVENT_ID_IO_ERROR_REASON,
    #     method(:dom_event_callback_io_error_reason).to_proc
    # )
    #
    # connection.domain_event_register_any(
    #     Libvirt::Connect::DOMAIN_EVENT_ID_GRAPHICS,
    #     method(:dom_event_callback_graphics).to_proc
    # )
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_REBOOT
  def dom_event_callback_reboot(_conn, dom, _opaque)
    LibvirtApp.logger.info { "DOMAIN EVENT REBOOT hv.id=#{id}, vm.id=#{dom.uuid}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE
  def dom_event_callback_lifecycle(dom, event, detail, _opaque)
    LibvirtApp.logger.info { "DOMAIN EVENT LIFECYCLE hv.id=#{id}, vm.id=#{dom}, event=#{event}, detail=#{detail}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_RTC_CHANGE
  def dom_event_callback_rtc_change(_conn, dom, utc_offset, _opaque)
    LibvirtApp.logger.info { "DOMAIN EVENT RTC_CHANGE hv.id=#{id}, vm.id=#{dom.uuid}, utc_offset=#{utc_offset}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_WATCHDOG
  def dom_event_callback_watchdog(_conn, dom, action, _opaque)
    LibvirtApp.logger.info { "DOMAIN EVENT WATCHDOG hv.id=#{id}, vm.id=#{dom.uuid}, action=#{action}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_IO_ERROR
  def dom_event_callback_io_error(_conn, dom, src_path, dev_alias, action, _opaque)
    LibvirtApp.logger.info { "DOMAIN EVENT IO_ERROR hv.id=#{id}, vm.id=#{dom.uuid}, src_path=#{src_path}, dev_alias=#{dev_alias}, action=#{action}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_IO_ERROR_REASON
  def dom_event_callback_io_error_reason(_conn, dom, src_path, dev_alias, action, _opaque)
    LibvirtApp.logger.info { "DOMAIN EVENT IO_ERROR_REASON hv.id=#{id}, vm.id=#{dom.uuid}, src_path=#{src_path}, dev_alias=#{dev_alias}, action=#{action}" }
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_GRAPHICS
  def dom_event_callback_graphics(_conn, dom, phase, local, remote, auth_scheme, subject, _opaque)
    LibvirtApp.logger.info { "DOMAIN EVENT GRAPHICS hv.id=#{id}, vm.id=#{dom.uuid}, phase=#{phase}, local=#{local}, remote=#{remote}, auth_scheme=#{auth_scheme}, subject=#{subject}" }
  end
end
