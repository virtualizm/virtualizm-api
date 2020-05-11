# frozen_string_literal: true

class StorageVolumesController < JsonApiController
  self.resource_class_name = 'StorageVolumeResource'

  before_action :authenticate_current_user!

  undef :create
  undef :update
  undef :destroy
end
