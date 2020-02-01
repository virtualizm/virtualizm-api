# frozen_string_literal: true

require 'securerandom'

module Rack
  RACK_X_REQUEST_ID = 'rack.x_request_id'

  class XRequestId
    def initialize(app, logger: nil)
      @app = app
      @logger = logger
    end

    def call(env)
      request_id = SecureRandom.uuid
      env[RACK_X_REQUEST_ID] = request_id
      status, headers, body = with_tags(request_id) { @app.call(env) }
      headers['X-Request-ID'] = env[RACK_X_REQUEST_ID]
      [status, headers, body]
    end

    private

    def with_tags(*tags)
      return yield if @logger.nil? || !@logger.respond_to?(:tagged)

      @logger.tagged(*tags) { yield }
    end
  end
end
