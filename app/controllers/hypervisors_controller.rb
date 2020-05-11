# frozen_string_literal: true

require_relative 'json_api_controller'

class HypervisorsController < JsonApiController
  self.resource_class_name = 'HypervisorResource'

  before_action :authenticate_current_user!

  undef :create
  undef :update
  undef :destroy
end
