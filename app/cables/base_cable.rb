class BaseCable < AsyncCable::Connection
  def on_data(data)
    logger.info { "#{self.class}/#{self.object_id.to_s(16)}/#{current_user.id} received #{data.inspect}" }
  end

  private

  def authorize_current_user!
    user_id = session['user_id']
    user = user_id ? User.find_by(id: user_id) : nil
    reject_unauthorized if user.nil?

    @current_user = user
  end

  attr_reader :current_user
  delegate :session, to: :request
end
