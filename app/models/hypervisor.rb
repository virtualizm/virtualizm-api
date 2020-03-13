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
    @on_close = []
    @on_open = []
    @on_vm_change = []

    # force connect to initialize events callbacks
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

  # @param event_id [Symbol]
  # @param vm [VirtualMachine,NilClass]
  # @param opaque [Object,NilClass]
  # @yieldparam conn [Libvirt::Connection]
  # @yieldparam dom [Libvirt::Domain]
  # @yieldparam *args [Array] specific event arguments
  # @yieldparam opaque [Object,NilClass]
  def register_vm_event_callback(event_id, vm = nil, opaque = nil, &block)
    connection.register_domain_event_callback(
        event_id,
        vm&.domain,
        opaque,
        &block
    )
  end

  # @yieldparam hv [Hypervisor]
  # @yieldparam vm [VirtualMachine]
  def on_vm_change(&block)
    @on_vm_change.push(block)
  end

  def connected?
    @is_connected
  end

  def on_close(&block)
    @on_close.push(block)
  end

  def on_open(&block)
    @on_open.push(block)
  end

  def create_stream
    connection.stream(Libvirt::Stream::NONBLOCK)
  end

  private

  def set_connection
    dbg { "#{self.class}#_open_connection Opening RW connection to name=#{name} id=#{id}, uri=#{uri}" }
    @connection = Libvirt::Connection.new(uri)
    _open_connection
  end

  def try_connect
    _open_connection
    if connected?
      Application.logger.info { "Hypervisor##{id} connected." }
      setup_attributes
      register_dom_event_callbacks
      register_close_callback
      load_virtual_machines
      @on_open.each { |cb| cb.call(self) }
    else
      Application.logger.info { "Hypervisor##{id} connect failed. Retry is scheduled." }
      schedule_try_connect
    end
  end

  def schedule_try_connect
    Async.run_after(Application.config.reconnect_timeout) do
      try_connect
    end
  end

  def register_close_callback
    connection.register_close_callback { |_c, reason, _op| when_closed(reason) }
  end

  def when_closed(reason)
    Application.logger.info { "Hypervisor##{id} connection was closed (#{reason}). Retry is scheduled." }
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
    @is_connected = true
  rescue Libvirt::Error => e
    dbg { "#{self.class}#_open_connection Failed #{e.message} name=#{name} id=#{id}, uri=#{uri}" }
    @is_connected = false
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
    connection.register_domain_event_callback(
        :LIFECYCLE,
        &method(:dom_event_callback_lifecycle)
    )
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE
  def dom_event_callback_lifecycle(_conn, dom, event, detail, _opaque)
    Application.logger.debug { "DOMAIN EVENT LIFECYCLE hv.id=#{id}, vm.id=#{dom.uuid}, event=#{event}, detail=#{detail}" }
    vm = virtual_machines.detect { |r| r.id == dom.uuid }

    vm.sync_state

    @on_vm_change.each do |block|
      Async.run_new { block.call(self, vm) }
    end
  end
end
