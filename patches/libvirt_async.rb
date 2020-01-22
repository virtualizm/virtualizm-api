require 'libvirt_async/handle'
require 'libvirt_async/timer'
require 'libvirt_async/util'
require 'libvirt'

STDOUT.puts 'LibvirtAsync PATCHES'

module LibvirtAsyncHandlePatch
  private

  def dispatch(events)
    dbg { "#{self.class}#dispatch starts handle_id=#{handle_id}, events=#{events}, fd=#{fd}" }

    task = LibvirtAsync::Util.create_task do
      dbg { "#{self.class}#dispatch async starts handle_id=#{handle_id} events=#{events}, fd=#{fd}" }
      Libvirt::event_invoke_handle_callback(handle_id, fd, events, opaque)
      dbg { "#{self.class}#dispatch async ends handle_id=#{handle_id} received_events=#{events}, fd=#{fd}" }
    end
    dbg { "#{self.class}#dispatch invokes fiber=0x#{task.fiber.object_id.to_s(16)} handle_id=#{handle_id}, events=#{events}, fd=#{fd}" }
    # task.run
    task.reactor << task.fiber ##

    dbg { "#{self.class}#dispatch ends handle_id=#{handle_id}, events=#{events}, fd=#{fd}" }
  end
end

module LibvirtAsyncTimerPatch
  private

  def dispatch
    dbg { "#{self.class}#dispatch starts timer_id=#{timer_id}, interval=#{interval}" }

    task = LibvirtAsync::Util.create_task do
      dbg { "#{self.class}#dispatch async starts timer_id=#{timer_id}, interval=#{interval}" }
      Libvirt::event_invoke_timeout_callback(timer_id, opaque)
      dbg { "#{self.class}#dispatch async async ends timer_id=#{timer_id}, interval=#{interval}" }
    end

    dbg { "#{self.class}#dispatch invokes fiber=0x#{task.fiber.object_id.to_s(16)} timer_id=#{timer_id}, interval=#{interval}" }
    # task.run
    task.reactor << task.fiber ##

    dbg { "#{self.class}#dispatch ends timer_id=#{timer_id}, interval=#{interval}" }
  end
end

LibvirtAsync::Handle.prepend LibvirtAsyncHandlePatch
LibvirtAsync::Timer.prepend LibvirtAsyncTimerPatch
