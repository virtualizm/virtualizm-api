# frozen_string_literal: true

require_relative 'json_api_controller'
require_relative '../resources/session_resource'

class SessionsController < JsonApiController
  self.resource_class = SessionResource

  undef :index
  undef :update
end
