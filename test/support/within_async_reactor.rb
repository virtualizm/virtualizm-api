# frozen_string_literal: true

require 'async/debug/selector'
require 'active_support/concern'

module WithinAsyncReactor
  extend ActiveSupport::Concern

  def run_in_reactor(reactor, duration = nil)
    result = nil

    timer_task = nil

    if duration
      timer_task = reactor.async do |task|
        # Wait for the timeout, at any point this task might be cancelled if the user code completes:
        task.annotate("timer task duration=#{duration}")
        task.sleep(duration)

        # The timeout expired, so generate an error:
        buffer = StringIO.new
        reactor.print_hierarchy(buffer)

        # Raise an error so it is logged:
        raise TimeoutError, "run time exceeded duration #{duration}s:\r\n#{buffer.string}"
      end
    end

    reactor.run do |task|
      task.annotate(self.class)

      spec_task = task.async do |current_task|
        current_task.annotate('running example')

        result = yield

        timer_task&.stop

        raise Async::Stop
      end

      begin
        timer_task&.wait
        spec_task.wait
      ensure
        spec_task.stop
      end
    end.wait

    result
  end

  def async_timeout
    ENV['ASYNC_TIMEOUT']
  end

  def run
    @__async_reactor = Async::Reactor.new(selector: Async::Debug::Selector.new)
    run_in_reactor(@__async_reactor, async_timeout) { super }
  end

  def async_schedule(parent = nil, &block)
    task = new_async_task(parent, &block)
    task.reactor << task.fiber
  end

  def async_run(parent = nil, &block)
    task = new_async_task(parent, &block)
    task.run
  end

  def new_async_task(parent = nil, &block)
    parent = Async::Task.current? if parent == :current
    Async::Task.new(@__async_reactor, parent, &block)
  end
end
