# frozen_string_literal: true

require 'active_support/concern'

module WithCacheMethods
  extend ActiveSupport::Concern

  class_methods do
    def define_cache(name, &block)
      var_name = :"@__cache__#{name}"
      define_method(name) do
        return instance_variable_get(var_name) if instance_variable_defined?(var_name)

        instance_variable_set(var_name, instance_exec(&block))
      end
      define_method(:after_teardown) do
        super()
        remove_instance_variable(var_name) if instance_variable_defined?(var_name)
      end
    end
  end
end
