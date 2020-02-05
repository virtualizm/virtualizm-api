# frozen_string_literal: true

class Factory
  class_attribute :_factories, instance_writer: false, default: {}
  class_attribute :_traits, instance_writer: false, default: (Hash.new { |h, k| h[k] = {} })
  class_attribute :_sequence, default: 0

  def self.define_trait(factory_name, trait_name, &block)
    raise ArgumentError, 'block is required' unless block_given?
    _traits[factory_name.to_sym][trait_name.to_sym] = block
  end

  def self.define_factory(factory_name, &block)
    raise ArgumentError, 'block is required' unless block_given?
    _factories[factory_name.to_sym] = block
  end

  def self.create(name, *args)
    Factory.new.call(name, *args)
  end

  def call(name, *args)
    attrs = args.extract_options!
    attrs = apply_traits(name, args, attrs)
    apply_factory(name, attrs)
  end

  private

  def sequence(&block)
    self._sequence += 1
    block ||= proc { |n| n }
    block.call(_sequence)
  end

  def create_struct(attrs = {}, &block)
    klass = Struct.new(*attrs.keys, &block)
    klass.new(*attrs.values)
  end

  def apply_traits(factory_name, trait_names, attrs)
    default_attrs = trait_names.each_with_object({}) do |trait_name, h|
      trait = _traits[factory_name.to_sym][trait_name.to_sym]
      raise ArgumentError "invalid trait #{trait}" if trait.nil?
      h.merge! instance_exec(h, &trait)
    end
    default_attrs.merge!(attrs)
    default_attrs
  end

  def apply_factory(factory_name, attrs)
    factory = _factories[factory_name.to_sym]
    raise ArgumentError "invalid factory #{factory_name}" if factory.nil?
    instance_exec(attrs, &factory)
  end

  define_factory :hypervisor do |attrs|
    node_info_attrs = attrs[:node_info] || {}
    node_info = create_struct(node_info_attrs)
    attrs = attrs.merge(node_info: node_info)
    id = attrs.delete(:id)
    uri = attrs.delete(:uri)
    name = attrs.delete(:name)
    ws_endpoint = attrs.delete(:ws_endpoint)
    conn_struct = create_struct(attrs) do
      def register_domain_event_callback(_ev, _dom = nil, _opaque = nil, &block)
        nil
      end
      def register_close_callback(_opaque = nil, &block)
        nil
      end
      def list_all_domains
        []
      end
      def open
        true
      end
    end

    Libvirt::Connection.stub(:new, conn_struct) do
      Hypervisor.new(id: id, name: name, uri: uri, ws_endpoint: ws_endpoint)
    end
  end

  define_trait :hypervisor, :default do
    {
        id: sequence,
        name: 'test',
        uri: 'uri',
        ws_endpoint: 'ws',
        version: '1.0',
        lib_version: '1.0',
        hostname: 'test',
        max_vcpus: 4,
        capabilities: [],
        node_info: {
            model: 'Test',
            cpus: '2',
            mhz: '3.6',
            nodes: '1',
            sockets: '123',
            cores: '4',
            threads: '1GB',
            memory: '1GB'
        }
    }
  end

  define_factory :virtual_machine do |attrs|
    hv = attrs.delete(:hypervisor) || attrs.delete(:hv)
    dom_struct = create_struct(attrs)

    VirtualMachine.new(hypervisor: hv, domain: dom_struct)
  end

  define_trait :virtual_machine, :default do
    # self.id = domain.uuid
    #     self.name = domain.name
    #     self.state = get_state
    #     self.cpus = get_cpus
    #     self.memory = domain.max_memory
    #     self.xml = domain.xml_desc
    {
        uuid: SecureRandom.uuid,
        name: 'test_dom',
        get_state: [:RUNNING, :BOOTED],
        max_vcpus: '1',
        vcpus: [Object.new],
        max_memory: '512MB',
        xml_desc: '<xml>test</xml>'
    }
  end

  define_trait :virtual_machine, :shut_off do
    {
        get_state: [5, 0]
    }
  end

end
