# frozen_string_literal: true

require 'active_support/all'
require 'libvirt_async'
require_relative '../../app/models/hypervisor'
require_relative 'stub_chain'

module StubLibvirt
  def wrap_application_load
    Hypervisor._storage = []

    chain = StubChain.new

    chain.add_stub LibvirtAsync, :register_implementations!, nil
    chain.add_stub Hypervisor, :load_storage, nil

    chain.use_stubs { yield }
  end

  module_function :wrap_application_load
end
