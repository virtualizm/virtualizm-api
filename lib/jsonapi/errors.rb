# frozen_string_literal: true

module JSONAPI
  module Errors
    class Serializable < JSONAPI::Serializable::Error
      attr_reader :object
      title { object.title }
      detail { object.detail }
      status { object.status.to_s }
    end

    class Error < StandardError
      def status
        raise NotImplementedError, "implement #status in #{self.class}"
      end

      def render_classes
        { self.class.name.to_sym => JSONAPI::Errors::Serializable }
      end

      def render_expose
        {}
      end

      def title
        message
      end

      def detail
        message
      end
    end

    class ServerError < Error
      def initialize
        super('server error')
      end

      def status
        500
      end
    end

    class BadRequest < Error
      def status
        400
      end
    end

    class NotFound < Error
      def initialize(msg)
        super("id #{msg} not found")
      end

      def status
        404
      end
    end

    class ValidationError < Error
      def status
        422
      end
    end

    class UnauthorizedError < Error
      def initialize
        super('unauthorized')
      end

      def status
        401
      end
    end
  end
end
