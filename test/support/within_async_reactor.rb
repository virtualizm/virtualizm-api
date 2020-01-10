require 'async/debug/selector'

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
        current_task.annotate("running example")

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

  def run
    reactor = Async::Reactor.new(selector: Async::Debug::Selector.new)
    timeout = ENV['ASYNC_TIMEOUT']
    run_in_reactor(reactor, timeout) { super }
  end
end
