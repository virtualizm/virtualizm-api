# frozen_string_literal: true

require_relative 'json_api_controller'

class SessionsController < JsonApiController
  self.resource_class_name = 'SessionResource'

  undef :index
  undef :update
end
