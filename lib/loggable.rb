# frozen_string_literal: true

module Loggable
  extend ActiveSupport::Concern

  class_methods do
    def logger
      Application.logger
    end

    def log_error(error, skip_backtrace: false, causes: [])
      return if logger.nil?

      logger.error do
        msg = ["<#{error.class}>: #{error.message}"]
        msg.concat(error.backtrace) unless skip_backtrace
        msg.join("\n")
      end

      return if error.cause.nil? || error.cause == error || causes.include?(error.cause)

      causes.push(error)
      log_error(error.cause, skip_backtrace: skip_backtrace, causes: causes)
    end

    def warn
      return if logger.nil?

      logger.error { yield }
    end

    def dbg
      return if logger.nil?

      meth_name = caller[0].split(%(`), 2).last.gsub(%('), '')
      prefix = "#{name}.#{meth_name}"
      logger.debug { "#{prefix} #{yield}" }
    end

    def info
      return if logger.nil?

      logger.info { yield }
    end
  end

  included do
    delegate :logger, :log_error, :warn, :info, to: self
  end

  def dbg
    return if logger.nil?

    meth_name = caller[0].split(%(`), 2).last.gsub(%('), '')
    prefix = "#{self.class}##{meth_name}"
    logger.debug { "#{prefix} #{yield}" }
  end
end
