# frozen_string_literal: true

require_relative 'base_controller'
require_relative 'concerns/user_authentication'
require_relative '../models/virtual_machine'

class SpiceController < BaseController
  class UnauthorizedError < StandardError
  end

  include Concerns::UserAuthentication

  before_action :authenticate_current_user!
  rescue_from UnauthorizedError, with: :respond_401

  def show
    id = path_params[:id]
    vm = VirtualMachine.find_by(id: id)
    return response(status: 404, body: nil) if vm.nil?

    ws_endpoint = vm.hypervisor.ws_endpoint
    graphics = Nokogiri::XML(vm.xml).xpath('/domain/devices/graphics')[0]
    spice_host = graphics.attributes['listen'].value
    spice_port = graphics.attributes['port'].value
    headers = {
        'X-Accel-Redirect': '@spice',
        'X-Spice-Url': "#{ws_endpoint}?host=#{spice_host}&port=#{spice_port}"
    }
    response(status: 200, headers: headers, body: nil)
  end

  private

  def respond_401(_e)
    response(status: 401, body: nil)
  end

  def authenticate_current_user!
    raise UnauthorizedError if current_user.nil?
  end
end
