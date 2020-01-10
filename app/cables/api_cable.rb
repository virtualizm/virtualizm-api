require_relative 'base_cable'

class ApiCable < BaseCable
  identified_as :api

  def on_open
    authorize_current_user!
    stream_for 'api'
  end

  def on_data(data)
    logger.info { "#{self.class}/#{self.object_id.to_s(16)}/#{current_user.id} received #{data.inspect}" }
  end
end
