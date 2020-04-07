# frozen_string_literal: true

module LDAP
  class Connection
    # @example
    # ldap_config = YAML.load_file('config/ldap.yml').deep_symbolize_keys
    # ldap = LDAP::Connection.new(ldap_config)
    # entry = ldap.authenticate!('login', 'password')
    # groups = ldap.groups(entry.dn)

    attr_accessor :options,
                  :search_attribute,
                  :required_groups,
                  :group_base,
                  :group_attribute

    class Error < StandardError
    end

    class ClientError < Error
      attr_reader :code, :ldap_message, :ldap_error_message, :result

      def initialize(result)
        @code = result.code
        @ldap_message = result.message
        @ldap_error_message = result.error_message
        @result = result
        msg = "#{result.code}: #{result.message}"
        msg += " (#{result.error_message})" if result.error_message.present?
        super(msg)
      end
    end

    class NotAuthorized < Error
    end

    # @param [Hash]
    #   :host [String] required.
    #   :port [Numeric] required.
    #   :attribute [String, Symbol] attribute by which login will be searched (default 'uid').
    #   :base [] base where user will be searched.
    #   :encryption [Symbol, nil] one of [:simple_tls] or nil.
    #   :group_base [String] base where user groups will be searched.
    #   :group_attribute [String] attribute by which user groups will be searched (default 'uniqueMember').
    #   :required_groups [Array<Hash>] groups in which user must be included to be authorized (default []).
    #     :base [String] base where user must be included.
    #     :attribute [String] attribute by which we check inclusion of user in base.
    #   :admin [Hash, nil] login credentials that should be checked on initialize connection (default nil).
    #     :dn [String] dn of login record.
    #     :password [String] password of login record.
    def initialize(options = {})
      ldap_options = options.slice(:encryption, :host, :port, :base)
      if ldap_options[:encryption]
        ldap_options[:encryption] = ldap_options[:encryption].to_sym
      else
        ldap_options.delete(:encryption)
      end

      @options = ldap_options

      if options[:admin]
        ldap = create_connection
        ldap.auth options[:admin][:dn], options[:admin][:password]
        raise NotAuthorized, 'admin dn or password incorrect' unless ldap.bind
      end

      @required_groups = options[:required_groups] || []
      @search_attribute = options[:attribute] || 'uid'

      @group_base = options[:group_base]
      @group_attribute = options[:group_attribute] || 'uniqueMember'
    end

    # @param login [String] will be searched by attribute option.
    # @param password [String]
    # @return [Net::LDAP::Entry] return ldap entry when authentication succeeds.
    # @raise [LDAP::Connection::Error] when failed to search in ldap.
    # @raise [LDAP::Connection::NotAuthorized] when authentication failed.
    def authenticate!(login, password)
      begin
        entry = find_by(search_attribute, login).first
      rescue ClientError => e
        warn e.message
        raise NotAuthorized, 'login is invalid' if e.ldap_message == 'Invalid Credentials'

        raise e
      end

      raise NotAuthorized, 'login is invalid' if entry.nil?

      ldap = create_connection
      ldap.auth(entry.dn, password)
      raise NotAuthorized, 'password is invalid' unless ldap.bind

      @required_groups.each do |base:, attribute:|
        raise NotAuthorized, "not included in group #{base}" unless in_group?(entry.dn, base, attribute)
      end

      entry
    end

    def find_login(login)
      find_by(search_attribute, login).first
    rescue ClientError => e
      warn e.message
      return if e.ldap_message == 'Invalid Credentials'

      raise e
    end

    # @param dn [String] dn value of user ldap entry.
    # @return [Array<String>] cn records of groups where user included.
    # @raise [LDAP::Connection::Error] when failed to search in ldap.
    def groups(dn)
      return [] if group_base.blank?

      groups = find_groups(dn, group_base, group_attribute)
      groups.map(&:cn).flatten
    end

    # @param login [String]
    # @param old_password [String]
    # @param new_password [String]
    # @raise [LDAP::Connection::Error] when failed to search or modify in ldap.
    # @raise [LDAP::Connection::NotAuthorized] when failed to authenticate by old_password.
    def change_password(login, old_password, new_password)
      entry = authenticate!(login, old_password)
      update_attribute(entry.dn, key: :userPassword, value: new_password)
    end

    private

    def create_connection
      Net::LDAP.new(options)
    end

    def find_by(attribute, value)
      ldap = create_connection

      filter = Net::LDAP::Filter.eq(attribute, value)
      entries = ldap.search(filter: filter)
      check_result!(ldap.get_operation_result)
      entries
    end

    def in_group?(dn, base, attribute)
      ldap = create_connection

      filter = Net::LDAP::Filter.eq(attribute, dn)
      entries = ldap.search(base: base, scope: Net::LDAP::SearchScope_BaseObject, filter: filter)
      check_result!(ldap.get_operation_result)
      entries.present?
    end

    def find_groups(dn, base, attribute)
      ldap = create_connection

      filter = Net::LDAP::Filter.eq(attribute, dn)
      groups = ldap.search(filter: filter, base: base)
      check_result!(ldap.get_operation_result)
      groups
    end

    def check_result!(result)
      return if result.code.zero?

      raise ClientError, result
    end

    def update_attribute(dn, key:, value:)
      ldap = create_connection

      # key - userPassword
      operations = [:replace, key, value]

      ldap.modify(dn: dn, operations: operations)
      check_result!(ldap.get_operation_result)
    end
  end
end
