# frozen_string_literal: true

class User
  class_attribute :_storage, instance_accessor: false

  class << self
    def load_storage(users)
      self._storage = users.map { |user_attrs| new(user_attrs) }
    end

    def authenticate(login:, password:)
      user = _storage.detect { |u| u.login == login }
      user&.authenticate?(password) ? user : nil
    end

    def all
      _storage
    end

    def find_by(id:)
      _storage.detect { |user| user.id.to_s == id.to_s }
    end
  end

  attr_accessor :id, :login, :password

  def initialize(attributes = {})
    assign_attributes(attributes)
  end

  def authenticate?(password)
    @password == password
  end

  def assign_attributes(attributes)
    attributes.each { |attr, value| public_send("#{attr}=", value) }
  end
end
