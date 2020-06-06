# frozen_string_literal: true

class NetworksController < JsonApiController
  self.resource_class_name = 'NetworkResource'

  before_action :authenticate_current_user!

  undef :create
  undef :update
  undef :destroy
end
