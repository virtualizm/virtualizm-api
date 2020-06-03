# frozen_string_literal: true

require_relative '../test_helper'

class TestVirtualMachines < RequestTestCase
  def teardown
    Hypervisor._storage = []
  end

  def setup
    @hv = Factory.create(:hypervisor, :default)
    @vm = Factory.create(:virtual_machine, :default, hv: hv)
    @vms = [
        @vm,
        Factory.create(:virtual_machine, :default, :shut_off, hv: hv)
    ]

    @hv.instance_variable_set(:"@virtual_machines", @vms)
    Hypervisor._storage = [@hv]
  end

  attr_reader :hv, :vms, :vm

  def test_get_virtual_machines_index_no_cookie
    get_json_api '/api/virtual-machines'
    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_virtual_machines_index_invalid_cookie
    set_cookie_header 'invalid-cookie'

    get_json_api '/api/virtual-machines'
    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_virtual_machines_index
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api '/api/virtual-machines'

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: [
                         {
                             id: vms.first.id,
                             type: 'virtual-machines',
                             attributes: {
                                 name: vms.first.name,
                                 state: 'running',
                                 tags: [],
                                 memory: vms.first.memory,
                                 cpus: vms.first.cpus,
                                 xml: vms.first.xml,
                                 graphics: [],
                                 disks: [],
                                 is_persistent: true,
                                 auto_start: true
                             },
                             relationships: {
                                 hypervisor: {
                                     links: { self: "/api/hypervisors/#{hv.id}" },
                                     data: { type: 'hypervisors', id: hv.id.to_s }
                                 },
                                 'storage-pools': {
                                     links: { self: "/api/virtual-machines/#{vms.first.id}/storage-pools" }
                                 },
                                 'storage-volumes': {
                                     links: { self: "/api/virtual-machines/#{vms.first.id}/storage-volumes" }
                                 }
                             },
                             links: { self: "/api/virtual-machines/#{vms.first.id}" }
                         },
                         {
                             id: vms.second.id,
                             type: 'virtual-machines',
                             attributes: {
                                 name: vms.second.name,
                                 state: 'shutoff',
                                 tags: [],
                                 memory: vms.second.memory,
                                 cpus: vms.second.cpus,
                                 xml: vms.second.xml,
                                 graphics: [],
                                 disks: [],
                                 is_persistent: true,
                                 auto_start: true
                             },
                             relationships: {
                                 hypervisor: {
                                     links: { self: "/api/hypervisors/#{hv.id}" },
                                     data: { type: 'hypervisors', id: hv.id.to_s }
                                 },
                                 'storage-pools': {
                                     links: { self: "/api/virtual-machines/#{vms.second.id}/storage-pools" }
                                 },
                                 'storage-volumes': {
                                     links: { self: "/api/virtual-machines/#{vms.second.id}/storage-volumes" }
                                 }
                             },
                             links: { self: "/api/virtual-machines/#{vms.second.id}" }
                         }
                     ]
  end

  def test_get_virtual_machines_index_fields
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api '/api/virtual-machines?fields[virtual-machines]=name,state'

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: [
                         {
                             id: vms.first.id,
                             type: 'virtual-machines',
                             attributes: {
                                 name: vms.first.name,
                                 state: 'running'
                             },
                             links: { self: "/api/virtual-machines/#{vms.first.id}" }
                         },
                         {
                             id: vms.second.id,
                             type: 'virtual-machines',
                             attributes: {
                                 name: vms.second.name,
                                 state: 'shutoff'
                             },
                             links: { self: "/api/virtual-machines/#{vms.second.id}" }
                         }
                     ]
  end

  def test_get_virtual_machines_index_include_hypervisor
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api '/api/virtual-machines?include=hypervisor'

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: [
                         {
                             id: vms.first.id,
                             type: 'virtual-machines',
                             attributes: {
                                 name: vms.first.name,
                                 state: 'running',
                                 tags: [],
                                 memory: vms.first.memory,
                                 cpus: vms.first.cpus,
                                 xml: vms.first.xml,
                                 graphics: [],
                                 disks: [],
                                 is_persistent: true,
                                 auto_start: true
                             },
                             relationships: {
                                 hypervisor: {
                                     links: { self: "/api/hypervisors/#{hv.id}" },
                                     data: { type: 'hypervisors', id: hv.id.to_s }
                                 },
                                 'storage-pools': {
                                     links: { self: "/api/virtual-machines/#{vms.first.id}/storage-pools" }
                                 },
                                 'storage-volumes': {
                                     links: { self: "/api/virtual-machines/#{vms.first.id}/storage-volumes" }
                                 }
                             },
                             links: { self: "/api/virtual-machines/#{vms.first.id}" }
                         },
                         {
                             id: vms.second.id,
                             type: 'virtual-machines',
                             attributes: {
                                 name: vms.second.name,
                                 state: 'shutoff',
                                 tags: [],
                                 memory: vms.second.memory,
                                 cpus: vms.second.cpus,
                                 xml: vms.second.xml,
                                 graphics: [],
                                 disks: [],
                                 is_persistent: true,
                                 auto_start: true
                             },
                             relationships: {
                                 hypervisor: {
                                     links: { self: "/api/hypervisors/#{hv.id}" },
                                     data: { type: 'hypervisors', id: hv.id.to_s }
                                 },
                                 'storage-pools': {
                                     links: { self: "/api/virtual-machines/#{vms.second.id}/storage-pools" }
                                 },
                                 'storage-volumes': {
                                     links: { self: "/api/virtual-machines/#{vms.second.id}/storage-volumes" }
                                 }
                             },
                             links: { self: "/api/virtual-machines/#{vms.second.id}" }
                         }
                     ],
                     included: [
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
                                 connected: true
                             },
                             relationships: {
                                 'virtual-machines': {
                                     links: { self: "/api/hypervisors/#{hv.id}/virtual-machines" }
                                 },
                                 'storage-pools': {
                                     links: { self: "/api/hypervisors/#{hv.id}/storage-pools" }
                                 }
                             },
                             links: { self: "/api/hypervisors/#{hv.id}" }
                         }
                     ]
  end

  def test_get_virtual_machines_show_no_cookie
    get_json_api "/api/virtual-machines/#{vm.id}"

    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_virtual_machines_show_invalid_cookie
    set_cookie_header 'invalid-cookie'

    get_json_api "/api/virtual-machines/#{vm.id}"

    assert_http_status 401
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '401',
                         title: 'unauthorized',
                         detail: 'unauthorized'
                     ]
  end

  def test_get_virtual_machines_show_invalid_id
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    uuid = SecureRandom.uuid
    get_json_api "/api/virtual-machines/#{uuid}"

    assert_http_status 404
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         {
                             status: '404',
                             title: "id #{uuid} not found",
                             detail: "id #{uuid} not found"
                         }
                     ]
  end

  def test_get_virtual_machines_show
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api "/api/virtual-machines/#{vm.id}"

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running',
                             tags: [],
                             memory: vm.memory,
                             cpus: vm.cpus,
                             xml: vm.xml,
                             graphics: [],
                             disks: [],
                             is_persistent: true,
                             auto_start: true
                         },
                         relationships: {
                             hypervisor: {
                                 links: { self: "/api/hypervisors/#{hv.id}" },
                                 data: { type: 'hypervisors', id: hv.id.to_s }
                             },
                             'storage-pools': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-pools" }
                             },
                             'storage-volumes': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-volumes" }
                             }
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     }
  end

  def test_get_virtual_machines_show_includes_hypervisor
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api "/api/virtual-machines/#{vm.id}?include=hypervisor"

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running',
                             tags: [],
                             memory: vm.memory,
                             cpus: vm.cpus,
                             xml: vm.xml,
                             graphics: [],
                             disks: [],
                             is_persistent: true,
                             auto_start: true
                         },
                         relationships: {
                             hypervisor: {
                                 links: { self: "/api/hypervisors/#{hv.id}" },
                                 data: { type: 'hypervisors', id: hv.id.to_s }
                             },
                             'storage-pools': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-pools" }
                             },
                             'storage-volumes': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-volumes" }
                             }
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     },
                     included: [
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
                                 connected: true
                             },
                             relationships: {
                                 'virtual-machines': {
                                     links: { self: "/api/hypervisors/#{hv.id}/virtual-machines" }
                                 },
                                 'storage-pools': {
                                     links: { self: "/api/hypervisors/#{hv.id}/storage-pools" }
                                 }
                             },
                             links: { self: "/api/hypervisors/#{hv.id}" }
                         }
                     ]
  end

  def test_get_virtual_machines_show_includes_hypervisor_with_fields
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api "/api/virtual-machines/#{vm.id}?include=hypervisor&fields[hypervisors]=name,connected"

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running',
                             tags: [],
                             memory: vm.memory,
                             cpus: vm.cpus,
                             xml: vm.xml,
                             graphics: [],
                             disks: [],
                             is_persistent: true,
                             auto_start: true
                         },
                         relationships: {
                             hypervisor: {
                                 links: { self: "/api/hypervisors/#{hv.id}" },
                                 data: { type: 'hypervisors', id: hv.id.to_s }
                             },
                             'storage-pools': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-pools" }
                             },
                             'storage-volumes': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-volumes" }
                             }
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     },
                     included: [
                         {
                             id: hv.id.to_s,
                             type: 'hypervisors',
                             attributes: {
                                 name: hv.name,
                                 connected: true
                             },
                             links: { self: "/api/hypervisors/#{hv.id}" }
                         }
                     ]
  end

  def test_get_virtual_machines_show_fields_includes_hypervisor_with_fields
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api "/api/virtual-machines/#{vm.id}?include=hypervisor&fields[virtual-machines]=name,state,hypervisor&fields[hypervisors]=name,connected"

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running'
                         },
                         relationships: {
                             hypervisor: {
                                 links: { self: "/api/hypervisors/#{hv.id}" },
                                 data: { type: 'hypervisors', id: hv.id.to_s }
                             }
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     },
                     included: [
                         {
                             id: hv.id.to_s,
                             type: 'hypervisors',
                             attributes: {
                                 name: hv.name,
                                 connected: true
                             },
                             links: { self: "/api/hypervisors/#{hv.id}" }
                         }
                     ]
  end

  def test_get_virtual_machines_show_fields
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api "/api/virtual-machines/#{vm.id}?fields[virtual-machines]=name,state"

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running'
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     }
  end

  def test_get_virtual_machines_show_fields_with_relationship
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    get_json_api "/api/virtual-machines/#{vm.id}?fields[virtual-machines]=name,state,hypervisor"

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running'
                         },
                         relationships: {
                             hypervisor: {
                                 links: { self: "/api/hypervisors/#{hv.id}" },
                                 data: { type: 'hypervisors', id: hv.id.to_s }
                             }
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     }
  end

  def test_patch_virtual_machines_state
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    patch_json_api "/api/virtual-machines/#{vm.id}", {
        data: {
            id: vm.id,
            type: 'virtual-machines',
            attributes: { state: 'running' }
        }
    }.to_json

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running',
                             tags: [],
                             memory: vm.memory,
                             cpus: vm.cpus,
                             xml: vm.xml,
                             graphics: [],
                             disks: [],
                             is_persistent: true,
                             auto_start: true
                         },
                         relationships: {
                             hypervisor: {
                                 links: { self: "/api/hypervisors/#{hv.id}" },
                                 data: { type: 'hypervisors', id: hv.id.to_s }
                             },
                             'storage-pools': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-pools" }
                             },
                             'storage-volumes': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-volumes" }
                             }
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     }
  end

  def test_patch_virtual_machines_tags
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie

    patch_json_api "/api/virtual-machines/#{vm.id}", {
        data: {
            id: vm.id,
            type: 'virtual-machines',
            attributes: { tags: [] }
        }
    }.to_json

    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: vm.id,
                         type: 'virtual-machines',
                         attributes: {
                             name: vm.name,
                             state: 'running',
                             tags: [],
                             memory: vm.memory,
                             cpus: vm.cpus,
                             xml: vm.xml,
                             graphics: [],
                             disks: [],
                             is_persistent: true,
                             auto_start: true
                         },
                         relationships: {
                             hypervisor: {
                                 links: { self: "/api/hypervisors/#{hv.id}" },
                                 data: { type: 'hypervisors', id: hv.id.to_s }
                             },
                             'storage-pools': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-pools" }
                             },
                             'storage-volumes': {
                                 links: { self: "/api/virtual-machines/#{vm.id}/storage-volumes" }
                             }
                         },
                         links: { self: "/api/virtual-machines/#{vm.id}" }
                     }
  end
end
