# frozen_string_literal: true

require_relative 'base_cable'

class DomainEventCable < BaseCable
  identified_as :domain_event

  STREAM_NAME = 'domain_event'

  def self.broadcast(data)
    super(STREAM_NAME, data)
  end

  def on_open
    authorize_current_user!
    stream_for STREAM_NAME
    logger.info { "#{to_s} opened current_user=#{current_user}" }
  end

  def on_close
    logger.info { "#{to_s} closed current_user=#{current_user} close_code=#{close_code}" }
  end

  def on_data(data)
    logger.info { "#{to_s} received data=#{data.inspect} current_user=#{current_user}" }
  end
end
