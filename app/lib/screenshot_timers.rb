class ScreenshotTimers
  include Singleton
  extend Forwardable
  extend SingleForwardable

  TIMEOUT = LibvirtApp.config.screenshot_timeout

  single_delegate [:add, :remove] => :instance
  instance_delegate [:synchronize] => :_mutex

  # @param vm [VirtualMachine]
  # @param display [Integer] default 0
  # @return [String, NilClass]
  def add(vm, display = 0)
    synchronize do
      key = key_for(vm, display)
      return if timers.key?(key)
      timers[key] = periodic_screenshot(vm, display)
    end
  end

  # @param vm [VirtualMachine]
  # @param display [Integer] default 0
  def remove(vm, display = 0)
    synchronize do
      key = key_for(vm, display)
      h = timers.delete(key)
      return if h.nil?
      h[:timer].cancel
      h[:streams].each(&:cancel)
    end
  end

  def _mutex
    @mutex ||= Mutex.new
  end

  private

  # @param vm [VirtualMachine]
  # @param display [Integer]
  # @param stream [VirtualMachine::Screenshot]
  def add_stream(vm, display, stream)
    key = key_for(vm, display)
    timers[key][:streams].push(stream)
  end

  # @param vm [VirtualMachine]
  # @param display [Integer]
  # @param stream [VirtualMachine::Screenshot]
  def remove_stream(vm, display, stream)
    key = key_for(vm, display)
    return unless timers.key?(key)
    timers[key][:streams].delete(stream)
  end

  # @param vm [VirtualMachine]
  # @param display [Integer] default 0
  # @return [String]
  def key_for(vm, display)
    [vm.hypervisor.id, vm.id, display].join('_')
  end

  # @param vm [VirtualMachine]
  # @param display [Integer]
  # @return [Hash]
  def periodic_screenshot(vm, display)
    logger.debug { "#{self.class}#periodic_screenshot started vm.id=#{vm.id} display=#{display}" }

    reactor = Async::Task.current.reactor
    first_stream = take_screenshot(vm, display)

    timer = reactor.every(TIMEOUT) do
      Async::Task.new(reactor, nil) do
        stream = take_screenshot(vm, display)
        add_stream(vm, display, stream) if stream
      end.run
    end

    streams = []
    streams.push(first_stream) if first_stream
    { timer: timer, streams: streams }
  end

  # @param vm [VirtualMachine]
  # @param display [Integer]
  def take_screenshot(vm, display)
    key = key_for(vm, display)
    file_path = LibvirtApp.root.join("public/screenshots/#{key}.pnm")
    stream = VirtualMachine::Screenshot.new(vm, file_path: file_path, display: display)

    stream.call do |success, reason|
      logger.debug { "#{self.class}#take_screenshot success=#{success} reason=#{reason} vm.id=#{vm.id} display=#{display} file_path=#{file_path}" }
      remove_stream(vm, display, stream)
      convert_screenshot(file_path) if success
    end
    stream
  rescue StandardError => e
    logger.error { "#{self.class}#take_screenshot unexpected exception vm.id=#{vm.id} display=#{display}" }
    logger.error { "#{e.class}>: #{e.message}\n#{e.backtrace.join("\n")}" }
  end

  def convert_screenshot(file_path)
    output_file_path = file_path.to_s.gsub /\.pnm$/, '.png'
    logger.debug { "#{self.class}#convert_screenshot output_file_path=#{output_file_path}" }

    image = MiniMagick::Image.open(file_path)
    image.format('png')
    image.write(output_file_path)
    logger.debug { "#{self.class}#convert_screenshot success output_file_path=#{output_file_path}" }
  end

  def timers
    @timers ||= {}
  end

  def logger
    LibvirtApp.logger
  end

  # initialize mutex while requiring code
  instance._mutex
end
