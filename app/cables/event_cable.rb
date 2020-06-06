# frozen_string_literal: true

require_relative 'base_cable'

class EventCable < BaseCable
  identified_as :event
  STREAM_NAME = 'event'

  class << self
    def vm_attributes(vm)
      { state: vm.state, tags: vm.tags, is_persistent: vm.is_persistent }
    end

    def pool_attributes(pool)
      { state: pool.state }
    end

    # @param net [Network]
    # @return [Hash]
    def net_attributes(net)
      { is_active: net.is_active, is_persisted: net.is_persisted, is_auto_run: net.is_auto_run }
    end

    def create_virtual_machine(vm)
      logger&.info(name) { "broadcast create_virtual_machine vm=#{vm.id}" }
      payload = { id: vm.id, hypervisor_id: vm.hypervisor.id }
      broadcast(type: 'create_virtual_machine', payload: payload)
    end

    def update_virtual_machine(vm)
      logger&.info(name) { "broadcast update_virtual_machine vm=#{vm.id}" }
      payload = { id: vm.id, hypervisor_id: vm.hypervisor.id, attributes: vm_attributes(vm) }
      broadcast(type: 'update_virtual_machine', payload: payload)
    end

    def destroy_virtual_machine(vm)
      logger&.info(name) { "broadcast destroy_virtual_machine vm=#{vm.id}" }
      payload = { id: vm.id, hypervisor_id: vm.hypervisor.id }
      broadcast(type: 'destroy_virtual_machine', payload: payload)
    end

    def create_storage_pool(pool)
      logger&.info(name) { "broadcast create_storage_pool pool=#{pool.uuid}, pool.name=#{pool.name}" }
      payload = { id: pool.uuid, hypervisor_id: pool.hypervisor.id }
      broadcast(type: 'create_storage_pool', payload: payload)
    end

    def update_storage_pool(pool)
      logger&.info(name) { "broadcast update_storage_pool pool=#{pool.uuid}, pool.name=#{pool.name}" }
      payload = { id: pool.uuid, hypervisor_id: pool.hypervisor.id, attributes: pool_attributes(pool) }
      broadcast(type: 'update_storage_pool', payload: payload)
    end

    def destroy_storage_pool(pool)
      logger&.info(name) { "broadcast destroy_storage_pool pool=#{pool.uuid}, pool.name=#{pool.name}" }
      payload = { id: pool.uuid, hypervisor_id: pool.hypervisor.id }
      broadcast(type: 'destroy_storage_pool', payload: payload)
    end

    def create_network(net)
      logger&.info(name) { "broadcast create_network net.uuid=#{net.uuid}, net.name=#{net.name}" }
      payload = { id: net.uuid, hypervisor_id: net.hypervisor.id }
      broadcast(type: 'create_network', payload: payload)
    end

    def update_network(net)
      logger&.info(name) { "broadcast create_network net.uuid=#{net.uuid}, net.name=#{net.name}" }
      payload = { id: net.uuid, hypervisor_id: net.hypervisor.id, attributes: net_attributes(net) }
      broadcast(type: 'update_network', payload: payload)
    end

    def destroy_network(net)
      logger&.info(name) { "broadcast create_network net.uuid=#{net.uuid}, net.name=#{net.name}" }
      payload = { id: net.uuid, hypervisor_id: net.hypervisor.id }
      broadcast(type: 'destroy_network', payload: payload)
    end

    def broadcast(data)
      super(STREAM_NAME, data)
    end
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
