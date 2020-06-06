# frozen_string_literal: true

class InterfacesController < JsonApiController
  self.resource_class_name = 'InterfaceResource'

  before_action :authenticate_current_user!

  undef :create
  undef :update
  undef :destroy
end
