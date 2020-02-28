# frozen_string_literal: true

class BaseController
  include ActiveSupport::Callbacks

  define_callbacks :action

  class_attribute :_exception_handlers, instance_writer: false, default: {}

  class << self
    # @param env [Hash]
    # @param action [Symbol]
    def call(env, action)
      new(env, action).call
    end

    # @param args [Array<Symbol,Hash>]
    # @yield block [Proc]
    # Usage:
    #   before_action :do_something, only: :show
    #   def do_something
    #     puts Time.now
    #   end
    #
    #   before_action except: [:index, :show] do
    #     puts Time.now
    #   end
    #
    def before_action(*args, &block)
      options = args.extract_options!
      callback = block_given? ? block : args.first
      set_action_callback(:before, callback, options)
    end

    # @param args [Array<Symbol,Hash>]
    # @yield block [Proc]
    # Usage:
    #   after_action :do_something, only: :show
    #   def do_something
    #     puts Time.now
    #   end
    #
    #   after_action except: [:index, :show] do
    #     puts Time.now
    #   end
    #
    def after_action(*args, &block)
      options = args.extract_options!
      callback = block_given? ? block : args.first
      set_action_callback(:after, callback, options)
    end

    # @param args [Array<Symbol,Hash>]
    # @yield block [Proc]
    # Usage:
    #   around_action :do_something, only: :show
    #   def do_something
    #     puts Time.now
    #     yield
    #     puts Time.now
    #   end
    #
    #   around_action except: [:index, :show] do |block|
    #     puts Time.now
    #     block.call
    #     puts Time.now
    #   end
    #
    def around_action(*args, &block)
      options = args.extract_options!
      callback = block_given? ? -> (_, action) { instance_exec(action, &block) } : args.first
      set_action_callback(:around, callback, options)
    end

    # @param type [Symbol] :before, :after, :around
    # @param callback [Proc,Symbol]
    # @param options [Hash]
    def set_action_callback(type, callback, options)
      options.assert_valid_keys(:only, :except, :if, :unless, :prepend)
      conditions = Array.wrap(options[:if])
      false_conditions = Array.wrap(options[:unless])
      prepend = options.fetch(:prepend, false)
      if options[:only] && options[:only] != :all
        conditions.push proc { Array.wrap(options[:only]).include?(@action) }
      end
      if options[:except]
        conditions.push proc { Array.wrap(options[:except]).exclude?(@action) }
      end

      set_callback(
          :action,
          type,
          callback,
          if: conditions,
          unless: false_conditions,
          prepend: prepend
      )
    end

    # @param exception_class [Class,Exception]
    # @param with [Proc, Symbol, NilClass] proc or method name
    # @yield
    # @yieldparam exception [Exception]
    # @yieldreturn [Array<Integer,Hash,String>] response
    def rescue_from(exception_class, with: nil, &block)
      raise ArgumentError, ":with option or block must be given" if with.nil? && !block_given?

      with = block if block_given?
      _exception_handlers.delete(exception_class)
      _exception_handlers.merge!(exception_class => with)
    end

    def inherited(subclass)
      subclass._exception_handlers = subclass._exception_handlers.dup
      super
    end

    def logger
      Application.logger
    end
  end

  attr_reader :env, :action

  # @param env [Hash]
  # @param action [Symbol]
  def initialize(env, action)
    @env = env
    @action = action
  end

  def call
    catch(:render) do
      run_callbacks :action do
        public_send(@action)
      end
    end
  rescue => exception
    rescue_with_handler(exception)
  end

  private

  # @param response [Array<Integer,Hash,String>]
  # @throw :render
  def halt(response)
    logger.debug { "Halt response chain with #{response[0]}." }
    throw(:render, response)
  end

  def logger
    self.class.logger
  end

  def rescue_with_handler(e)
    klass = _exception_handlers.keys.reverse.detect { |k| e.is_a?(k) }
    raise e if klass.nil?

    handler = _exception_handlers.fetch(klass)
    logger.debug { "rescue from exception <#{e.class}: #{e.message}> with handler #{klass} #{handler}" }
    handler = method(handler).to_proc if handler.is_a?(Symbol)
    instance_exec(e, &handler)
  end

  def path_params
    return @path_params if defined?(@path_params)
    @path_params = env[Rack::Router::RACK_ROUTER_PATH_HASH] || {}
  end

  def query_params
    return @query_params if defined?(@query_params)
    @query_params = request.GET.deep_symbolize_keys
  end

  def json_body
    return @json_body if defined?(@json_body)
    @json_body = JSON.parse(request.body.read, symbolize_names: true)
  end

  def response(status:, body:, headers: {})
    payload = body.nil? ? [] : [body]
    [status.to_i, headers.stringify_keys, payload]
  end

  def request
    @request ||= Rack::Request.new(env)
  end

  delegate :session, :cookies, to: :request

  def log_error(e, skip_backtrace: false)
    logger.error { "<#{e.class}>: #{e.message}\n#{e.backtrace&.join("\n") unless skip_backtrace}" }
    log_error(e.cause, skip_backtrace: skip_backtrace) if e.cause && e.cause != e
  end
end
