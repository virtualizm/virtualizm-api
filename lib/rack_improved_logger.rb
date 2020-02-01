# frozen_string_literal: true

module Rack
  class ImprovedLogger
    attr_reader :logger

    def initialize(app, logger = nil)
      @app = app
      @logger = logger || Logger.new(STDOUT)
    end

    def call(env)
      began_at = Utils.clock_time
      log_start(env)
      status, headers, body = @app.call(env)
      log_end(env, began_at, status, headers, body)
      [status, headers, body]
    end

    private

    def log_start(env)
      http_method = env['REQUEST_METHOD']
      path = env['PATH_INFO']
      query = env['QUERY_INFO'].presence
      # content_type = env['CONTENT_TYPE']
      # accept = env['HTTP_ACCEPT']
      logger.info { "Started #{http_method} #{path}#{"?#{query}" if query}\n" }
    end

    def log_end(env, began_at, status, _headers, _body)
      ends_at = Utils.clock_time
      took = (ends_at - began_at) * 1_000
      logger.info { "Responds with #{status} (took #{took.round(3)} ms)." }
    end
  end
end
