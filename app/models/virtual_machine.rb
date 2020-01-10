class VirtualMachine
  include LibvirtAsync::WithDbg

  # https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainState
  STATE_RUNNING = 1
  STATES = {
      0 => "no state",
      1 => "running",
      2 => "blocked on resource",
      3 => "paused by user",
      4 => "being shut down",
      5 => "shut off",
      6 => "crashed",
      7 => "suspended by guest power management",
  }.freeze

  attr_reader :domain,
              :hypervisor

  attr_accessor :id,
                :name,
                :cpus,
                :memory,
                :state,
                :xml

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
  end

  def setup_attributes
    self.id = domain.uuid
    self.name = domain.name
    self.state = get_state
    self.cpus = get_cpus
    self.memory = domain.max_memory
    self.xml = domain.xml_desc
  end

  def tags
    nil
  end

  def running?
    state == STATES[STATE_RUNNING]
  end

  def get_cpus
    if running?
      domain.max_vcpus
    else
      domain.vcpus.count
    end
  end

  def get_state
    dbg { "#{self.class}#state retrieving id=#{id}" }
    libvirt_state, _ = domain.state
    dbg { "#{self.class}#state retrieved id=#{id} libvirt_state=#{libvirt_state}" }
    STATES[libvirt_state]
  end

  # def start
  #   domain.create
  # rescue Libvirt::Error => exception
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
