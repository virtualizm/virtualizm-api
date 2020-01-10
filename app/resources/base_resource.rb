class BaseResource
  class_attribute :_filters, instance_accessor: false, default: {}
  class_attribute :_object_class_name, instance_accessor: false

  class << self
    # @param class_or_name [String, Class]
    def object_class(class_or_name)
      @_object_class = nil
      if class_or_name.is_a?(String)
        self._object_class_name = class_or_name
      elsif class_or_name.is_a?(Class)
        @_object_class = class_or_name
        self._object_class_name = class_or_name.name
      else
        raise ArgumentError, "class name or class must be provided"
      end
    end

    def _object_class
      @_object_class ||= _object_class_name.constantize
    end

    def inherited(subclass)
      subclass._filters = _filters.dup
      super
    end

    # @param name [Symbol, String]
    # @param options [Hash]
    def filter(name, options = {})
      _filters.merge(name.to_sym => options)
    end

    def find_collection(options)
      context = options[:context]
      scope = records(options)
      scope = apply_filters(scope, options[:filters], context)
      apply_includes(scope, options[:includes], context)
    end

    def find_single(key, options)
      context = options[:context]
      scope = records(options)
      scope = apply_includes(scope, options[:includes], context)
      object = find_object(scope, key, context)
      raise JSONAPI::Errors::NotFound, key if object.nil?
      object
    end

    def apply_filters(scope, filters, context)
      filters.each do |filter_name, raw_value|
        value = parse_filter_value(filter_name, raw_value, context)
        scope = apply_filter(scope, filter_name, value, context)
      end
      scope
    end

    def apply_includes(scope, includes, context)
      includes.each do |include|
        scope = apply_include(scope, include, context)
      end
      scope
    end

    def parse_filter_value(filter_name, raw_value, _context)
      value = raw_value.to_s.split(',')
      block = _filters[filter_name][:verify]
      if block
        block = method(block).to_proc if block.is_a?(Symbol)
        block.call(scope, value, context)
      end
      value
    end

    def apply_filter(scope, filter_name, value, context)
      block = _filters[filter_name][:apply]
      if block
        block = method(block).to_proc if block.is_a?(Symbol)
        block.call(scope, value, context)
      else
        apply_default_filter(scope, filter_name, value, context)
      end
    end

    def allowed_fields
      attribute_blocks.keys + relationship_blocks.keys
    end

    def records(_options)
      _model_class.all
    end

    def find_object(scope, key, _context)
      # scope.find(key)
      scope.detect { |r| r.id == key }
    end

    def apply_include(scope, _include, _context)
      # scope.preload(include)
      scope
    end

    def apply_default_filter(scope, filter_name, value, _context)
      # scope.where(filter_name => value)
      scope.select { |r| value.include? r.public_send(filter_name) }
    end

    def create(_data, _options)
      raise NotImplementedError, "override .create in #{name}"
    end

    def destroy(_object, _options)
      raise NotImplementedError, "override .create in #{name}"
    end

    def render_classes
      { _object_class.name.to_sym => self::Serializable }
    end
  end
end
