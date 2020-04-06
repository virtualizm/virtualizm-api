# frozen_string_literal: true

class User
  class_attribute :_strategy, instance_accessor: false

  class BaseStrategy
    def initialize(*_args); end

    def load
      raise NotImplementedError, "override #load in #{self.class}"
    end

    # @param login [String]
    # @param password [String]
    # @return [User, nil]
    def authenticate(_login, _password)
      raise NotImplementedError, "override #authenticate in #{self.class}"
    end

    # @return [Array<User>]
    def all
      raise NotImplementedError, "override #all in #{self.class}"
    end
  end

  class StorageStrategy < BaseStrategy
    def initialize(users)
      @users = users.map { |user_attrs| User.new(user_attrs) }
    end

    def authenticate(login, password)
      user = @users.detect { |u| u.login == login }
      user&.password == password ? user : nil
    end

    def all
      @users
    end
  end

  class LdapStrategy < BaseStrategy
    def initialize(ldap_config)
      @ldap = LDAP::Connection.new(ldap_config.deep_symbolize_keys)
      @users = []
    end

    def authenticate(login, password)
      entry = @ldap.authenticate!(login, password)
      User.new(
          id: entry['uidnumber']&.first,
          login: login,
          email: entry['mail']&.first,
          full_name: entry['cn']&.first
      )
    rescue LDAP::Connection::NotAuthorized => _e
      nil
    end

    def all
      @users
    end
  end

  class << self
    def load_strategy(name, *args)
      klass = "::User::#{name.to_s.classify}Strategy".constantize
      self._strategy = klass.new(*args)
    end

    def authenticate(login:, password:)
      _strategy.authenticate(login, password)
    end

    def all
      _strategy.all
    end

    def find_by(id:)
      all.detect { |user| user.id.to_s == id.to_s }
    end
  end

  attr_accessor :id, :login, :password, :email, :full_name

  def initialize(attributes = {})
    assign_attributes(attributes)
  end

  def assign_attributes(attributes)
    attributes.each { |attr, value| public_send("#{attr}=", value) }
  end
end
