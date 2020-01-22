ENV['RACK_ENV'] = 'test'

require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'])

# https://wiki.debian.org/HowToGetABacktrace
# https://www.tutorialspoint.com/gnu_debugger/index.htm

require 'minitest/autorun'
require 'rack/test'
require 'minitest/reporters'
require 'active_support/all'
require 'get_process_mem'
require_relative '../test/support/within_async_reactor'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require_relative '../config/environment'
# require_relative '../patches/libvirt_async'

$test_storage = {}

class Opaque
  CALLBACK = proc do |s, ev, op|
    # GC.start
    next unless (Libvirt::Stream::EVENT_READABLE & ev) != 0
    begin
      code, data = s.recv(256 * 1024)
    rescue Libvirt::Error => e
      op.on_libvirt_error(s, e)
      next
    end
    # GC.start

    case code
    when 0
      op.on_complete(s)
    when -1
      op.on_recv_error(s)
    when -2
      STDOUT.puts "Opaque::CALLBACK #{op.filepath} wait for data"
    else
      op.on_receive(data)
    end
  end

  attr_reader :filepath

  def initialize(filepath, finish_cb)
    @filepath = filepath
    @f = File.open(@filepath, 'wb')
    @finish_cb = finish_cb
  end

  def on_complete(stream)
    STDOUT.puts "Opaque#on_complete #{@filepath}"
    success, reason = finish_stream(stream)
    finish(success, reason)
  end

  def on_receive(data)
    STDOUT.puts "Opaque#on_receive #{@filepath} #{data&.size}"
    @f.write(data)
  end

  def on_recv_error(stream)
    STDOUT.puts "Opaque#on_recv_error #{@filepath}"
    success, reason = finish_stream(stream)
    finish(success, reason)
  end

  def on_libvirt_error(stream, e)
    STDOUT.puts "Opaque#on_libvirt_error #{@filepath} #{e}"
    success, reason = finish_stream(stream)
    finish(success, reason)
  end

  private

  def finish_stream(stream)
    STDOUT.puts "Opaque#finish_stream stream.event_remove_callback #{@filepath}"
    stream.event_remove_callback
    result = begin
      STDOUT.puts "Opaque#finish_stream stream.finish #{@filepath}"
      stream.finish
      [true, nil]
    rescue Libvirt::Error => e
      STDERR.puts "Opaque#finish_stream stream.finish exception rescued #{e.class} #{e.message}"
      [false, e.message]
    end
    STDOUT.puts "Opaque#finish_stream ends #{@filepath}"
    result
  end

  def finish(success, reason)
    STDOUT.puts "Opaque#finish success=#{success} #{@filepath}"

    @f.close
    # @f = nil
    @finish_cb.call(success, reason)
    # @finish_cb = nil
  end
end

class TestSessions < Minitest::Test
  include WithinAsyncReactor

  def setup
    require 'gc_tracer'
    GC::Tracer.start_logging

    print_usage 'SETUP'
    LibvirtAsync.use_logger!(STDOUT)
    LibvirtAsync.logger.level = ENV['LIBVIRT_DEBUG'] ? :debug : :info
    LibvirtAsync.register_implementations!
    config = {
        id: 1,
        name: 'dev.local',
        uri: 'qemu+tcp://localhost:16510/system'
    }
    Hypervisor.load_storage [config.stringify_keys]
  end

  def teardown
    print_usage 'TEARDOWN'
    GC.start
  end

  def test_screenshot_mem
    print_usage 'test_screenshot_mem start'
    hv = Hypervisor.all.first
    vm = hv.virtual_machines.first

    1.times do |i|
      print_usage "test_screenshot_mem #{i} start block"
      stream = hv.connection.stream(Libvirt::Stream::NONBLOCK)

      opaque_cb = proc do |success|
        puts "Stream #{i} complete success=#{success}"
        print_usage "after stream #{i} complete stream=#{$test_storage["stream#{i}"]}"
        GC.start
        print_usage "after stream #{i} complete and GC.start"
        $test_storage.delete("stream#{i}")
        # GC.start
        print_usage "after stream #{i} delete and GC.start"
        async_teardown if $test_storage.empty?
      end

      opaque = Opaque.new("tmp/screenshots_test#{i}.pnm", opaque_cb)

      $test_storage["stream#{i}"] = stream

      print_usage "test_screenshot_mem #{i} before stream start"
      vm.domain.screenshot(stream, 0)
      stream.event_add_callback(
          Libvirt::Stream::EVENT_READABLE,
          Opaque::CALLBACK,
          opaque
      )
      print_usage "test_screenshot_mem #{i} end block"
    end

    print_usage 'test_screenshot_mem end'
    GC.start
    print_usage 'test_screenshot_mem end after GC.start'

  rescue => e
    STDERR.puts "#{e.class}>: #{e.message}", e.backtrace
    exit 1
  end

  def print_usage(description)
    mb = GetProcessMem.new.mb
    STDOUT.puts ">>> #{description} - MEMORY USAGE: #{mb} MB"
  end

  def async_teardown
    async_schedule do
      STDOUT.puts "async_teardown $test_storage=#{$test_storage}"
      Hypervisor.all.each { |hv| hv.connection.close }
      LibvirtAsync.unregister_implementations!
      async_schedule do
        Async::Task.current.reactor.sleep(2)
        # GC.start(full_mark: true, immediate_sweep: true)
      end
    end
  end
end
