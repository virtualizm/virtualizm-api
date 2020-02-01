# frozen_string_literal: true

require_relative 'json_api_controller'
require_relative '../resources/hypervisor_resource'

class HypervisorsController < JsonApiController
  self.resource_class = HypervisorResource

  before_action :authenticate_current_user!

  undef :create
  undef :update
  undef :destroy
end
