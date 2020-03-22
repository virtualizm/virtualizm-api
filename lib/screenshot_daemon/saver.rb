# frozen_string_literal: true

module ScreenshotDaemon
  class Saver
    CALLBACK = ->(stream, events, opaque) do
      return unless (Libvirt::Stream::EVENT_READABLE & events) != 0

      begin
        code, data = stream.recv(opaque.chunk_size)
        case code
        when 0
          opaque.finish(true)
        when -1
          raise Libvirt::RecvError, 'error code -1 received'
        when -2 # rubocop:disable Lint/EmptyWhen
          # nothing
        else
          opaque.write(data)
        end
      rescue Libvirt::Errors::Error => e
        opaque.finish(false, e.message)
      rescue StandardError => e
        opaque.finish(false, "#{e.class}: #{e.message}")
        raise e
      end
    end.freeze

    def self.call(vm, *args)
      new(vm, *args).call
    end

    attr_reader :chunk_size

    # @param vm [VirtualMachine]
    # @param path [String]
    # @param display [Integer] default 0
    # @param chunk_size [Integer] default 1024
    # @yield when saving complete (success/failed/cancelled)
    def initialize(vm, path, display: 0, chunk_size: 1024)
      @vm = vm
      @path = path
      @display = display
      @chunk_size = chunk_size

      @tmp_path = nil
      @tmp_file = nil
      @stream = nil
    end

    def call
      @tmp_path = "/tmp/libvirt_screenshot_tmp_#{SecureRandom.hex(32)}_#{Time.now.to_i}.pnm"
      fd = IO.sysopen(@tmp_path, 'wb')
      io = IO.new(fd)
      io_wrapper = Async::IO::Generic.new(io)
      @tmp_file = Async::IO::Stream.new(io_wrapper)

      @stream = @vm.take_screenshot(self, &CALLBACK)
    rescue Libvirt::Errors::Error => e
      finish(false, e.message)
    rescue StandardError => e
      finish(false, "#{e.class}: #{e.message}")
      raise e
    end

    def write(data)
      @tmp_file.write(data)
    end

    def finish(success, reason = nil)
      if success
        @tmp_file.close
        convert(@tmp_path, @path)
        log(:info) { "screenshot save succeed vm=#{@vm.id}, path=#{@path}," }
      else
        log(:error) { "screenshot save failed vm=#{@vm.id}, reason=#{reason}," }
      end
    ensure
      cleanup
    end

    def cancel
      log(:info) { "screenshot save canceled vm=#{@vm.id}," }
      cleanup
    end

    private

    def convert(input_path, output_path)
      ext = File.extname(output_path).gsub(/^\./, '')

      image = MiniMagick::Image.open(input_path)
      image.format(ext)
      image.write(output_path)
      image.tempfile.close
      image.destroy!
    end

    def cleanup
      @tmp_file&.close
      FileUtils.rm_f(@tmp_path) if @tmp_path && File.exist?(@tmp_path)

      begin
        @stream&.event_remove_callback
      rescue Libvirt::Errors::Error => e
        dbg('#cleanup') { "stream event_remove_callback error message=#{e.message}, vm=#{@vm.id}, path=#{@path}," }
      end

      begin
        @stream&.finish
      rescue Libvirt::Errors::Error => e
        dbg('#cleanup') { "stream finish error message=#{e.message}, vm=#{@vm.id}, path=#{@path}," }
      end

      @stream = nil
    end

    def log(level, progname = nil, &block)
      Application.logger&.public_send(level, progname, &block)
    end

    def dbg(meth, &block)
      log(:debug, "<#{self.class}#0x#{object_id.to_s(16)}>##{meth}", &block)
    end
  end
end
