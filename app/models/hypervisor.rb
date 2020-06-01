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
    @on_pool_change = []
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

  def on_pool_change(&block)
    @on_pool_change.push(block)
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
    dbg { "creating Libvirt::Connection to #{hv_info}, uri=#{uri}" }
    @connection = Libvirt::Connection.new(uri)
    @is_connected = false
    dbg { "created #{hv_info}, uri=#{uri}" }
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
    dbg { "registering close callback #{hv_info}" }
    result = connection.register_close_callback { |_c, reason, _op| when_closed(reason) }
    dbg { "registered close callback #{hv_info}" }
    result
  end

  def when_closed(reason)
    info { "#{hv_info} connection was closed (#{reason}). Retry is scheduled." }

    dbg { "calling on_close size=#{@on_close.size} #{hv_info}" }
    @on_close.each { |cb| cb.call(self) }
    dbg { "called on_close size=#{@on_close.size} #{hv_info}" }

    @virtual_machines = []
    @storage_pools = []
    try_connect
  end

  def load_virtual_machines
    dbg { "loading #{hv_info}" }

    domains = connection.list_all_domains
    dbg { "loaded size=#{domains.size} #{hv_info}" }

    @virtual_machines = domains.map do |vm|
      VirtualMachine.new(domain: vm, hypervisor: self)
    end

    dbg { "initialized size=#{virtual_machines.size} #{hv_info}" }
  end

  def load_storage_pools
    dbg { "loading #{hv_info}" }

    pools = connection.list_all_storage_pools
    dbg { "loaded size=#{pools.size} #{hv_info}" }

    @storage_pools = pools.map do |sp|
      StoragePool.new(sp, hypervisor: self)
    end

    dbg { "initialized size=#{storage_pools.size} #{hv_info}" }
  end

  def _open_connection
    dbg { "connecting #{hv_info}, uri=#{uri}" }

    connection.open
    dbg { "connected #{hv_info}, uri=#{uri}" }

    interval = Application.config.keep_alive_interval
    count = Application.config.keep_alive_count
    if interval && count
      connection.set_keep_alive(interval, count)
      dbg { "set keep alive interval=#{interval}, count,#{count} #{hv_info}" }
    end

    @is_connected = true
  rescue Libvirt::Errors::Error => e
    dbg { "Failed #{e.message} #{hv_info}, uri=#{uri}" }
    @is_connected = false
  end

  def setup_attributes
    dbg { "setting up #{hv_info}" }

    self.version = connection.version
    dbg { "version set #{hv_info}" }

    self.libversion = connection.lib_version
    dbg { "libversion set #{hv_info}" }

    self.hostname = connection.hostname
    dbg { "hostname set #{hv_info}" }

    self.max_vcpus = connection.max_vcpus
    dbg { "max_vcpus set #{hv_info}" }

    self.capabilities = connection.capabilities
    dbg { "capabilities set #{hv_info}" }

    node_info = connection.node_info
    self.cpu_model = node_info.model
    self.cpus = node_info.cpus
    self.mhz = node_info.mhz
    self.numa_nodes = node_info.nodes
    self.cpu_sockets = node_info.sockets
    self.cpu_cores = node_info.cores
    self.cpu_threads = node_info.threads
    self.total_memory = Libvirt::Util.parse_memory(node_info.memory, :KiB)
    dbg { "node_info set #{hv_info}" }

    self.free_memory = connection.free_memory

    dbg { "free_memory set #{hv_info}" }
  end

  def register_dom_event_callbacks
    dbg { "started #{hv_info}" }

    connection.register_domain_event_callback(
        :LIFECYCLE,
        &method(:dom_event_callback_lifecycle)
    )
    dbg { "register_domain_event_callback LIFECYCLE registered #{hv_info}" }

    connection.register_domain_event_callback(
        :METADATA_CHANGE,
        &method(:dom_event_callback_metadata_change)
    )
    dbg { "register_domain_event_callback METADATA_CHANGE registered #{hv_info}" }

    connection.register_storage_pool_event_callback(
        :LIFECYCLE,
        &method(:storage_event_callback_lifecycle)
    )
    dbg { "register_storage_pool_event_callback LIFECYCLE registered #{hv_info}" }

    connection.register_storage_pool_event_callback(
        :REFRESH,
        &method(:storage_event_callback_refresh)
    )
    dbg { "register_storage_pool_event_callback REFRESH registered #{hv_info}" }
  end

  def storage_event_callback_lifecycle(_conn, pool, event, detail, _opaque)
    dbg { "STORAGE POOL EVENT LIFECYCLE #{hv_info}, #{pool_info(pool)}, event=#{event}, detail=#{detail}" }
    sp = storage_pools.detect { |r| r.uuid == pool.uuid }
    if sp.nil?
      sp = StoragePool.new(pool, hypervisor: self)
      dbg { "STORAGE POOL ADDED #{hv_info}, #{pool_info(pool)}" }
      storage_pools << sp
      pool_changed(:create, sp)
      return
    end

    if event == :UNDEFINED
      dbg { "STORAGE POOL REMOVED #{hv_info}, #{pool_info(pool)}" }
      storage_pools.delete(sp)
      sp.state = event.to_s.downcase
      sp.volumes = []
      pool_changed(:destroy, sp)
      return
    end

    dbg { "STORAGE POOL CHANGED #{hv_info}, #{pool_info(pool)}" }
    sp.sync_state
    pool_changed(:update, sp)
  end

  def storage_event_callback_refresh(_conn, pool, _opaque)
    dbg { "STORAGE POOL EVENT REFRESH #{hv_info}, #{pool_info(pool)}" }
    # do nothing for now.
  end

  # Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE
  def dom_event_callback_lifecycle(_conn, dom, event, detail, _opaque)
    dbg { "DOMAIN EVENT LIFECYCLE #{hv_info}, #{dom_info(dom)}, event=#{event}, detail=#{detail}" }
    vm = virtual_machines.detect { |r| r.id == dom.uuid }

    if vm.nil?
      vm = VirtualMachine.new(domain: dom, hypervisor: self)
      dbg { "DOMAIN ADDED #{hv_info}, #{dom_info(dom)}" }
      virtual_machines << vm
      vm_changed(:create, vm)
      return
    end

    if event == :UNDEFINED || (event == :STOPPED && !vm.is_persistent)
      dbg { "DOMAIN REMOVED #{hv_info}, #{dom_info(dom)}" }
      virtual_machines.delete(vm)
      vm.state = event.to_s.downcase
      vm_changed(:destroy, vm)
      return
    end

    dbg { "DOMAIN CHANGED #{hv_info}, #{dom_info(dom)}" }
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

  def pool_changed(action, pool)
    @on_pool_change.each do |block|
      Async.run_new { block.call(action, pool) }
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

  def pool_info(pool)
    "pool.id=#{pool.uuid}, pool.name=#{pool.name}"
  end
end
