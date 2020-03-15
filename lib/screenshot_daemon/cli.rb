# frozen_string_literal: true

require 'optparse'

module ScreenshotDaemon
  class CLI
    def self.run
      new.run
    end

    def initialize
      @timeout = 30
      @debug = !!ENV['DEBUG'] # rubocop:disable Style/DoubleNegation
      @quiet = false

      OptionParser.new do |opts|
        opts.banner = 'Usage: screenshot-daemon [options]'

        opts.on('-tN', '--timeout=N', 'take screenshot every N seconds (default 30)') do |timeout|
          @timeout = Float(timeout)
        end

        opts.on('-d', '--[no-]debug', 'Debug logging') do |debug|
          @debug = debug
        end

        opts.on('-q', '--[no-]quiet', 'no logging') do |quiet|
          @quiet = quiet
        end
      end.parse!
    end

    def run
      STDOUT.puts 'Starting Screenshot Daemon',
                  "Debug: #{@debug}",
                  "Timeout: #{@timeout}",
                  "Quiet: #{@quiet}",
                  "PID: #{Process.pid}"

      Application.logger.level = @debug ? :debug : :info
      Application.logger = nil if @quiet
      Libvirt.logger = Application.logger

      Runner.run(@timeout)
    end
  end
end
