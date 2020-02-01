# frozen_string_literal: true

class ScreenshotTimers
  include Singleton
  extend Forwardable
  extend SingleForwardable

  include LibvirtAsync::WithDbg

  single_delegate [:add, :remove, :run, :enabled?] => :instance

  def enabled?
    LibvirtApp.config.screenshot_enabled
  end

  def run
    Async.run_new do
      logger.info "VM screenshot save starting..."
      VirtualMachine.all.each do |vm|
        if vm.running?
          LibvirtApp.logger.info "> VM #{vm.id} state is #{vm.state} so started"
          Async.schedule_new { ScreenshotTimers.add(vm) }
          Async.current_reactor.sleep 2
        else
          LibvirtApp.logger.info "> VM #{vm.id} state is #{vm.state} so skipping"
        end
      end
      LibvirtApp.logger.info "OK."
    end
  end

  # @param vm [VirtualMachine]
  # @param display [Integer] default 0
  # @return [Boolean]
  def add(vm, display = 0)
    key = key_for(vm, display)
    return false if timers.key?(key)
    initiate_screenshot(vm, display, true)
    true
  end

  # @param vm [VirtualMachine]
  # @param display [Integer] default 0
  # @return[Boolean]
  def remove(vm, display = 0)
    key = key_for(vm, display)
    return false unless timers.key?(key)
    timer, stream = timers.delete(key)
    timer.cancel
    stream.cancel
    true
  end

  private

  def screenshot_timeout
    LibvirtApp.config.screenshot_timeout
  end

  # @param vm [VirtualMachine]
  # @param display [Integer]
  # @param now [Boolean] run now (default false)
  def initiate_screenshot(vm, display, now = false)
    result = create_screenshot(vm, display, now) do
      key = key_for(vm, display)
      was_active = timers.key?(key)
      initiate_screenshot(vm, display) if was_active
    end

    key = key_for(vm, display)
    timers[key] = result
    nil
  end

  # @param vm [VirtualMachine]
  # @param display [Integer]
  # @param now [Boolean] run now or after timeout
  # @return [Array] timer, stream
  # @yield after screenshot completed or failed
  def create_screenshot(vm, display, now, &block)
    stream = create_stream(vm, display)

    timeout = now ? 0 : screenshot_timeout

    timer = Async.run_after(timeout) do
      logger.debug { "#{self.class}#create_screenshot started vm.id=#{vm.id} display=#{display}" }
      k = SecureRandom.hex(12)
      TrackTime.start_track(vm, display, k)
      stream.call do |success, reason|
        file_path = file_path_for(vm, display)
        spent = TrackTime.end_track(vm, display, k).to_s
        logger.debug { "#{self.class}#create_screenshot completed success=#{success} reason=#{reason} vm.id=#{vm.id} display=#{display} file_path=#{file_path} spent=#{spent}ms" }
        convert_screenshot(file_path) if success
        block.call(success, reason)
      end
    end

    [timer, stream]
  end

  # @param vm [VirtualMachine]
  # @param display [Integer]
  # @return [VirtualMachine::Screenshot]
  def create_stream(vm, display)
    file_path = file_path_for(vm, display)
    VirtualMachine::Screenshot.new(vm, file_path: file_path, display: display)
  end

  # @param vm [VirtualMachine]
  # @param display [Integer]
  # @return [String]
  def file_path_for(vm, display)
    key = key_for(vm, display)
    LibvirtApp.root.join("public/screenshots/#{key}.pnm")
  end

  # @param vm [VirtualMachine]
  # @param display [Integer] default 0
  # @return [String]
  def key_for(vm, display)
    display == 0 ? vm.id : "#{vm.id}_#{display}"
  end

  # @param file_path [String]
  def convert_screenshot(file_path)
    logger.debug { "#{self.class}#convert_screenshot started file_path=#{file_path}" }
    output_file_path = file_path.to_s.gsub(/\.pnm$/, '.png')

    TrackTime.track do
      image = MiniMagick::Image.open(file_path)
      image.format('png')
      image.write(output_file_path)
      image.tempfile.close
      image.destroy!
    end
    spent = TrackTime.last_track.to_s
    logger.debug { "#{self.class}#convert_screenshot completed output_file_path=#{output_file_path} spent=#{spent}ms" }
  end

  def timers
    @timers ||= {}
  end

  def logger
    LibvirtApp.logger
  end
end
