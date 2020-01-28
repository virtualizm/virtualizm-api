require_relative '../test_helper'

class TestSpice < RequestTestCase
  def teardown
    Hypervisor._storage = []
  end

  def setup
    @hv = Factory.create(:hypervisor, :default)
    @vm = Factory.create(:virtual_machine, :default, hv: hv)
    @hv.instance_variable_set(:"@virtual_machines", [@vm])
    Hypervisor._storage = [@hv]
  end

  attr_reader :hv, :vm

  def test_get_spice_no_cookie
    get "/api/spice/#{vm.id}"
    assert_http_status 401
    assert_response_body ''
  end

  def test_get_spice_invalid_cookie
    set_cookie_header 'invalid-cookie'

    get "/api/spice/#{vm.id}"
    assert_http_status 401
    assert_response_body ''
  end

  def test_get_spice_invalid_id
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    uuid = SecureRandom.uuid
    get "/api/spice/#{uuid}"

    assert_http_status 404
    assert_response_body ''
  end

  def test_get_spice
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    vm.xml = <<-XML
      <domain type='kvm' id='1'>
        <devices>
          <graphics type='spice' port='5900' autoport='yes' listen='1.2.3.4'>
            <listen type='address' address='1.2.3.4'/>
            <image compression='off'/>
          </graphics>
        </devices>
      </domain>
    XML

    get "/api/spice/#{vm.id}"

    assert_http_status 200
    assert_response_headers(
        'x-accel-redirect': '@spice',
        'x-spice-url': "#{hv.ws_endpoint}?host=1.2.3.4&port=5900"
    )
  end
end
