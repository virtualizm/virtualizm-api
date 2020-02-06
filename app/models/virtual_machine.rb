# frozen_string_literal: true

require 'tempfile'
require 'securerandom'

class VirtualMachine
  include LibvirtAsync::WithDbg

  class Screenshot
    # Usage:
    #   sc = VirtualMachine::Screenshot.call(vm, file_path: file_path, display: display) do |success, reason|
    #     success ? puts("screenshot saved at #{file_path}") : STDERR.puts("screenshot failed with #{reason}")
    #   end
    #   sleep 30
    #   sc.cancel if sc.active?
    #

    include LibvirtAsync::WithDbg

    # @param vm [VirtualMachine]
    # @param file_path [String]
    # @param display [Integer] default 0
    # @yield when screenshot save succeed or failed
    # @yieldparam success [Boolean]
    # @yieldparam reason [String,NilClass] error reason when success is false
    # @return [VirtualMachine::Screenshot]
    def self.call(vm, file_path:, display: 0, &block)
      instance = new(vm, file_path: file_path, display: display)
      instance.call(&block)
      instance
    end

    attr_reader :vm, :file_path, :display

    # @param vm [VirtualMachine]
    # @param file_path [String]
    # @param display [Integer] default 0
    def initialize(vm, file_path:, display: 0)
      @vm = vm
      @file_path = file_path.to_s
      @display = display
      cleanup
    end

    # @yield when screenshot save succeed or failed
    # @yieldparam success [Boolean]
    # @yieldparam reason [String,NilClass] error reason when success is false
    # @return [VirtualMachine::Screenshot]
    def call(&block)
      @block = block
      # @tmp_file = Tempfile.new('', nil, mode: File::Constants::BINARY)
      # @tmp_file_path = @tmp_file.path
      @tmp_file_path = "/tmp/libvirt_screenshot_tmp_#{SecureRandom.hex(32)}_#{Time.now.to_i}"
      fd = IO.sysopen(@tmp_file_path, 'wb')
      io = IO.new(fd)
      io_wrapper = Async::IO::Generic.new(io)
      @tmp_file = Async::IO::Stream.new(io_wrapper)

      dbg { "#{self.class}#call tmp file created tmp vm.id=#{vm.id}, tmp_file.path=#{@tmp_file_path}" }

      @stream = LibvirtAsync::StreamRead.new(vm.hypervisor.connection, @tmp_file)
      vm_state = vm.get_state
      dbg { "#{self.class}#call check state vm_state=#{vm_state}, vm.id=#{vm.id}" }
      mime_type = vm.domain.screenshot(@stream.stream, display)
      dbg { "#{self.class}#call mime_type=#{mime_type}, vm.id=#{vm.id}, tmp_file.path=#{@tmp_file_path}" }

      @stream.call { |success, reason, _io| on_complete(success, reason) }
    rescue Libvirt::Error => e
      dbg { "#{self.class}#call libvirt exception id=#{vm.id}, e=<#{e.class}: #{e.message}>" }
      on_complete(false, e.message)
    end

    def active?
      !@stream.nil?
    end

    def cancel
      @stream&.cancel
      true
    rescue Libvirt::Error => _e
      false
    ensure
      cleanup
    end

    private

    # @param success [Boolean]
    # @param reason [String,NilClass]
    def on_complete(success, reason)
      dbg { "#{self.class}#on_complete success=#{success} reason=#{reason} id=#{vm.id}" }

      @tmp_file.close
      FileUtils.mv(@tmp_file_path, file_path) if success
      FileUtils.rm(@tmp_file_path, force: true) unless success
      cb = @block
      cleanup
      cb.call(success, reason)
    end

    def cleanup
      @tmp_file&.close
      FileUtils.rm(@tmp_file_path, force: true) if @tmp_file_path && File.exist?(@tmp_file_path)

      @block = nil
      @stream = nil
      @tmp_file = nil
      @tmp_file_path = nil
    end

    def logger
      LibvirtApp.logger
    end
  end

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
    state == 'running'
  end

  def get_cpus
    if running?
      domain.max_vcpus
    else
      # domain.vcpus.count
    end
  end

  def get_state
    state, _ = domain.get_state
    state.to_s.downcase
  end

  # @param [Symbol]
  # @raise [ArgumentError]
  # @raise [Libvirt::Error]
  def set_state(state)
    case state
    when :RUNNING
      domain.start
    when :SHUTDOWN
      domain.shutdown(1)
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
  end

  # Take screenshot asynchronously.
  # @param file_path [String]
  # @param display [Integer]
  # @yield when success or failed
  # @yieldparam success [Boolean]
  # @yieldparam reason [String,NilClass] error reason
  # @return [VirtualMachine::Screenshot] respond to #cancel which will cancel screenshot saving.
  def take_screenshot(file_path, display: 0, &block)
    Screenshot.call(self, file_path: file_path, display: display, &block)
  end

  def on_event(event_id, opaque = nil, &block)
    hypervisor.on_domain_event(
        event_id,
        domain,
        opaque,
        &block
    )
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
