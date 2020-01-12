require_relative 'base_cable'

class ApiCable < BaseCable
  identified_as :api

  def on_open
    authorize_current_user!
    stream_for 'api'
    logger.info { "#{to_s} opened current_user=#{current_user}" }
  end

  def on_close
    logger.info { "#{to_s} closed current_user=#{current_user} close_code=#{close_code}" }
  end

  def on_data(data)
    logger.info { "#{to_s} received data=#{data.inspect} current_user=#{current_user}" }
  end
end
