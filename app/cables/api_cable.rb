# frozen_string_literal: true

require_relative 'base_cable'

class ApiCable < BaseCable
  identified_as :api

  def on_open
    authorize_current_user!
    stream_for 'api'
    logger.info { "#{self} opened current_user=#{current_user}" }
  end

  def on_close
    logger.info { "#{self} closed current_user=#{current_user} close_code=#{close_code}" }
  end

  def on_data(data)
    logger.info { "#{self} received data=#{data.inspect} current_user=#{current_user}" }
  end
end
