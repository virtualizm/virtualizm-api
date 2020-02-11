# frozen_string_literal: true

require_relative 'base_cable'

class EventCable < BaseCable
  identified_as :event
  STREAM_NAME = 'event'

  def self.update_virtual_machine(vm)
    logger&.info(name) { "broadcast update_virtual_machine vm=#{vm.id}" }
    payload = { id: vm.id, hypervisor_id: vm.hypervisor.id, attributes: { state: vm.state } }
    broadcast(type: 'update_virtual_machine', payload: payload)
  end

  def self.broadcast(data)
    super(STREAM_NAME, data)
  end

  def on_open
    authorize_current_user!
    stream_for STREAM_NAME
    log(:info, to_s) { "opened current_user=#{current_user}" }
  end

  def on_close
    log(:info, to_s) { "closed current_user=#{current_user} close_code=#{close_code}" }
  end
end
