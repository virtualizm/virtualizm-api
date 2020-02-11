# frozen_string_literal: true

module ScreenshotDaemon
  class Runner
    def self.run(timeout)
      new(timeout).run
    end

    def initialize(timeout)
      @timeout = timeout
    end

    def run
      run_once

      Async.run_every @timeout do
        run_once
      end
    end

    def run_once
      virtual_machines.each do |vm|
        log(:info) { "screenshot save started for vm #{vm.id}" }
        Saver.call vm, screenshot_path(vm)
      end
    end

    private

    def screenshot_path(vm)
      LibvirtApp.root.join("public/screenshots/#{vm.id}.png")
    end

    def virtual_machines
      vms = []

      Hypervisor.all.each do |hv|
        unless hv.connected?
          log(:info) { "screenshot save skipped for hv #{hv.id} because not connected" }
          next
        end

        hv.virtual_machines.each do |vm|
          unless vm.running?
            log(:info) { "screenshot save skipped for vm #{vm.id} because not running" }
            next
          end

          vms.push(vm)
        end
      end

      vms
    end

    def log(level, progname = nil, &block)
      LibvirtApp.logger&.public_send(level, progname, &block)
    end

    def dbg(meth, &block)
      log(:debug, "<#{self.class}#0x#{object_id.to_s(16)}>##{meth}", &block)
    end
  end
end
