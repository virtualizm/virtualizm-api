# frozen_string_literal: true

class Hypervisor
  include ::Loggable

  class_attribute :_storage, instance_accessor: false

  class << self
    def load_storage(clusters)
      dbg { clusters }
      self._storage = clusters.map do |cluster|
        Hypervisor.new(**cluster.symbolize_keys)
      end
      dbg { "loaded size=#{_storage.size}" }
    end

    def all
      dbg { 'started' }
      result = _storage
      dbg { "found size=#{result.size}" }
      result
    end

    def find_by(id:)
      dbg { "id=#{id}" }
      result = _storage.detect { |hv| hv.id.to_s == id.to_s }
      dbg { "found id=#{result&.id}, name=#{result&.name}, uri=#{result&.uri}" }
      result
    end
  end

  attr_reader :id,
              :name,
              :uri,
              :ws_endpoint,
              :virtual_machines,
              :connection,
              :storage_pools

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
    dbg { "id=#{id}, name=#{name}, uri=#{uri}, ws_endpoint=#{ws_endpoint}" }

    @id = id
    @name = name
    @uri = uri
    @ws_endpoint = ws_endpoint
    @on_close = []
    @on_open = []
    @on_vm_change = []
    @virtual_machines = []
    @storage_pools = []

    # force connect to initialize events callbacks
    set_connection
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

  def try_connect
    _open_connection

    unless connected?
      info { "#{hv_info} connect failed. Retry is scheduled." }
      schedule_try_connect
      return
    end

    info { "#{hv_info} connected." }
    setup_attributes
    register_dom_event_callbacks
    register_close_callback
    load_virtual_machines
    load_storage_pools
    @on_open.each { |cb| cb.call(self) }
  rescue StandardError => e
    log_error(e)
    info { "#{hv_info} connect failed due to error. Retry is scheduled." }
    schedule_try_connect
  end

  private

  def set_connection
    dbg { "Opening RW connection to #{hv_info}, uri=#{uri}" }
    @connection = Libvirt::Connection.new(uri)
    @is_connected = false
  rescue StandardError => e
    log_error(e)
  end

  def schedule_try_connect
    Async.run_after(Application.config.reconnect_timeout) do
      try_connect
    end
  rescue StandardError => e
    log_error(e)
    raise e
  end

  def register_close_callback
    connection.register_close_callback { |_c, reason, _op| when_closed(reason) }
  end

  def when_closed(reason)
    info { "#{hv_info} connection was closed (#{reason}). Retry is scheduled." }
    @on_close.each { |cb| cb.call(self) }
    @virtual_machines = []
    @storage_pools = []
    try_connect
  end

  def load_virtual_machines
    dbg { "#{hv_info}, uri=#{uri}" }

    @virtual_machines = connection.list_all_domains.map do |vm|
      VirtualMachine.new(domain: vm, hypervisor: self)
    end

    dbg { "loaded size=#{virtual_machines.size} #{hv_info}, uri=#{uri}" }
  end

  def load_storage_pools
    dbg { hv_info }

    @storage_pools = connection.list_all_storage_pools.map do |sp|
      StoragePool.new(sp, hypervisor: self)
    end

    dbg { "loaded size=#{storage_pools.size} #{hv_info}, uri=#{uri}" }
  end

  def _open_connection
    connection.open
    # c.set_keep_alive(10, 2)
    dbg { "Connected #{hv_info}, uri=#{uri}" }
    @is_connected = true
  rescue Libvirt::Errors::Error => e
    dbg { "Failed #{e.message} #{hv_info}, uri=#{uri}" }
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
    self.total_memory = Libvirt::Util.parse_memory(node_info.memory, :KiB)
    self.free_memory = connection.free_memory
  end

  def register_dom_event_callbacks
    connection.register_domain_event_callback(
        :LIFECYCLE,
        &method(:dom_event_callback_lifecycle)
    )

    connection.register_domain_event_callback(
        :METADATA_CHANGE,
        &method(:dom_event_callback_metadata_change)
    )
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE
  def dom_event_callback_lifecycle(_conn, dom, event, detail, _opaque)
    dbg { "DOMAIN EVENT LIFECYCLE #{hv_info}, #{dom_info(dom)}, event=#{event}, detail=#{detail}" }
    vm = virtual_machines.detect { |r| r.id == dom.uuid }

    if vm.nil?
      vm = VirtualMachine.new(domain: dom, hypervisor: self)
      dbg { "DOMAIN ADD #{hv_info}, #{dom_info(dom)}" }
      virtual_machines << vm
      vm_changed(:create, vm)
      return
    end

    if event == :UNDEFINED || (event == :STOPPED && !vm.is_persistent)
      dbg { "DOMAIN REMOVE #{hv_info}, #{dom_info(dom)}" }
      virtual_machines.delete(vm)
      vm.state = event.to_s.downcase
      vm_changed(:destroy, vm)
      return
    end

    vm.sync_state
    vm.sync_persistent
    vm_changed(:update, vm)
  rescue StandardError => e
    log_error(e)
  end

  def dom_event_callback_metadata_change(_conn, dom, type, uri, _opaque)
    dbg { "DOMAIN EVENT METADATA_CHANGE #{hv_info}, #{dom_info(dom)}, type=#{type}, uri=#{uri}" }
    return if type != :ELEMENT || uri != VirtualMachine::TAGS_URI

    vm = virtual_machines.detect { |r| r.id == dom.uuid }
    vm.sync_tags

    vm_changed(:update, vm)
  rescue StandardError => e
    log_error(e)
  end

  def vm_changed(action, vm)
    @on_vm_change.each do |block|
      Async.run_new { block.call(action, vm) }
    end
  end

  def hv_info
    "hv.id=#{id}, hv.name=#{name}"
  end

  def dom_info(dom)
    "dom.id=#{dom.uuid}, dom.name=#{dom.name}, dom.persistent=#{dom.persistent?}"
  rescue Libvirt::Errors::LibError => _e
    # when domain already deleted we can't check if it's persisted or not
    "dom.id=#{dom.uuid}, dom.name=#{dom.name}"
  end
end
