# frozen_string_literal: true

require_relative '../test_helper'

class TestHypervisors < RequestTestCase
  def teardown
    Hypervisor._storage = []
  end

  def setup
    @hv = Factory.create(:hypervisor, :default)
    Hypervisor._storage = [@hv]
  end

  attr_reader :hv

  def test_get_hypervisors_index_no_cookie
    get_json_api '/api/hypervisors'
    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_hypervisors_index_invalid_cookie
    set_cookie_header 'invalid-cookie'
    get_json_api '/api/hypervisors'
    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_hypervisors_index
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api '/api/hypervisors'

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: [
                         {
                             id: hv.id.to_s,
                             type: 'hypervisors',
                             attributes: {
                                 name: hv.name,
                                 version: hv.version,
                                 libversion: hv.libversion,
                                 hostname: hv.hostname,
                                 max_vcpus: hv.max_vcpus,
                                 cpu_model: hv.cpu_model,
                                 cpus: hv.cpus,
                                 mhz: hv.mhz,
                                 numa_nodes: hv.numa_nodes,
                                 cpu_sockets: hv.cpu_sockets,
                                 cpu_cores: hv.cpu_cores,
                                 cpu_threads: hv.cpu_threads,
                                 total_memory: hv.total_memory,
                                 free_memory: hv.free_memory,
                                 capabilities: hv.capabilities,
                                 running: true
                             },
                             links: { self: "/api/hypervisors/#{hv.id}" }
                         }
                     ]
  end

  def test_get_hypervisors_show_no_cookie
    get_json_api "/api/hypervisors/#{hv.id}"

    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_hypervisors_show_invalid_cookie
    set_cookie_header 'invalid-cookie'

    get_json_api "/api/hypervisors/#{hv.id}"

    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_hypervisors_show_invalid_id
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api '/api/hypervisors/999999'

    assert_http_status 404
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         {
                             status: '404',
                             title: 'id 999999 not found',
                             detail: 'id 999999 not found',
                         }
                     ]
  end

  def test_get_hypervisors_show
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api "/api/hypervisors/#{hv.id}"

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: hv.id.to_s,
                         type: 'hypervisors',
                         attributes: {
                             name: hv.name,
                             version: hv.version,
                             libversion: hv.libversion,
                             hostname: hv.hostname,
                             max_vcpus: hv.max_vcpus,
                             cpu_model: hv.cpu_model,
                             cpus: hv.cpus,
                             mhz: hv.mhz,
                             numa_nodes: hv.numa_nodes,
                             cpu_sockets: hv.cpu_sockets,
                             cpu_cores: hv.cpu_cores,
                             cpu_threads: hv.cpu_threads,
                             total_memory: hv.total_memory,
                             free_memory: hv.free_memory,
                             capabilities: hv.capabilities,
                             running: true
                         },
                         links: { self: "/api/hypervisors/#{hv.id}" }
                     }
  end
end
