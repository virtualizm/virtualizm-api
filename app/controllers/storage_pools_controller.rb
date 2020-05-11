# frozen_string_literal: true

class StoragePoolsController < JsonApiController
  self.resource_class_name = 'StoragePoolResource'

  before_action :authenticate_current_user!

  undef :create
  undef :update
  undef :destroy
end
