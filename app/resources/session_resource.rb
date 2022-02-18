# frozen_string_literal: true

require_relative 'base_resource'

class SessionResource < BaseResource
  class Serializable < JSONAPI::Serializable::Resource
    type :sessions
    attributes :login
    id { 'sessions' }
  end

  class Deserializable < JSONAPI::Deserializable::Resource
    attributes :login, :password
  end

  object_class 'User'

  class << self
    def find_single(_key, options)
      context = options[:context]
      user_id = context[:request].session['user_id']
      user = user_id ? User.find_by(id: user_id) : nil
      raise JSONAPI::Errors::NotFound, 'session' if user.nil?

      user
    end

    def create(data, options)
      context = options[:context]
      user = User.authenticate(**data)
      raise JSONAPI::Errors::ValidationError.new(:data, 'login or password invalid') if user.nil?

      context[:request].session['user_id'] = user.id
      user
    end

    def destroy(_object, options)
      context = options[:context]
      user_id = context[:request].session['user_id']
      user = user_id ? User.find_by(id: user_id) : nil
      raise JSONAPI::Errors::NotFound, 'session' if user.nil?

      context[:request].session['user_id'] = nil
    end
  end
end
