require_relative 'base_cable'

class DomainEventCable < BaseCable
  identified_as :domain_event

  def on_open
    authorize_current_user!
    stream_for 'domain_event'
  end
end
