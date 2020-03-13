# frozen_string_literal: true

require 'async'

module Async
  # @param timeout [Integer]
  # @yield periodic when timeout pass
  # @yieldparam [Async::Task]
  # @return timer
  def run_every(timeout, &block)
    reactor = current_reactor
    current_reactor.every(timeout) do
      run_new(nil, reactor, &block)
    end
  end

  # @param timeout [Integer]
  # @yield periodic when timeout pass
  # @yieldparam [Async::Task]
  # @return timer
  def run_after(timeout, &block)
    reactor = current_reactor
    current_reactor.after(timeout) do
      run_new(nil, reactor, &block)
    end
  end

  # @return [Async::Reactor] current reactor.
  def current_reactor
    Async::Task.current.reactor
  end

  # @param [Async::Task]
  def schedule_task(task)
    task.reactor << task.fiber
    nil
  end

  # @param parent [Symbol,NilClass,Async::Task]
  # @yield inside new Fiber
  # @yieldparam [Async::Task] task
  # @return [Async::Task] created task
  def run_new(parent = nil, reactor = nil, &block)
    task = new_task(parent, reactor, &block)
    task.run
    task
  end

  # @param parent [Symbol,NilClass,Async::Task]
  # @yield inside new Fiber
  # @yieldparam [Async::Task] task
  # @return [Async::Task] created task
  def schedule_new(parent = nil, reactor = nil, &block)
    task = new_task(parent, reactor, &block)
    schedule_task(task)
    task
  end

  # @param parent [Symbol,NilClass,Async::Task]
  # @yield inside new Fiber
  # @yieldparam [Async::Task] task
  # @return [Async::Task] created task
  def new_task(parent = nil, reactor = nil, &block)
    reactor ||= current_reactor
    parent = Async::Task.current? if parent == :current
    Async::Task.new(reactor, parent, &block)
  end

  module_function :run_new,
                  :schedule_new,
                  :new_task,
                  :current_reactor,
                  :schedule_task,
                  :run_every,
                  :run_after
end
