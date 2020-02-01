# frozen_string_literal: true

require_relative 'json_api_controller'
require_relative '../resources/virtual_machine_resource'

class VirtualMachinesController < JsonApiController
  self.resource_class = VirtualMachineResource

  before_action :authenticate_current_user!

  undef :create
  undef :update
  undef :destroy
end
