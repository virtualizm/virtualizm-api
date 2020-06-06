# frozen_string_literal: true

require 'base64'

module NameToId
  module_function

  def encode(name)
    return if name.nil?

    Base64.urlsafe_encode64(name).gsub('=', '_')
  end

  def decode(id)
    return if id.nil?

    Base64.urlsafe_decode64 id.gsub('_', '=')
  end
end
