# frozen_string_literal: true

require_relative 'json_api_controller'

class VirtualMachinesController < JsonApiController
  self.resource_class_name = 'VirtualMachineResource'

  before_action :authenticate_current_user!

  undef :create
  undef :destroy
end
