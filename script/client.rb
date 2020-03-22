# frozen_string_literal: true

begin
  require 'bundler/inline'
  require 'bundler'
rescue LoadError => e
  warn 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

gemfile(true, ui: Bundler::UI::Silent.new) do
  source 'https://rubygems.org'

  gem 'httparty'
  gem 'websocket-client-simple'
  gem 'activesupport'
end

require 'httparty'
require 'websocket-client-simple'
require 'active_support/all'

module JsonApiClient
  MIME_TYPE = 'application/vnd.api+json'

  def self.default_headers
    { 'Accept': MIME_TYPE, 'Content-Type': MIME_TYPE }
  end

  def self.parse_response(response)
    response_body = begin
                      JSON.parse(response.body, symbolize_names: true)
                    rescue StandardError
                      nil
                    end
    [response.code, response_body, response.headers]
  end

  def self.get(uri, headers: {}, **opts)
    headers = default_headers.merge(headers)
    response = HTTParty.get(uri, headers: headers, **opts)
    parse_response(response)
  end

  def self.post(uri, headers: {}, body: {}, **opts)
    body = body.to_json unless body.is_a?(String)
    headers = default_headers.merge(headers)
    response = HTTParty.post(uri, headers: headers, body: body, **opts)
    parse_response(response)
  end

  def self.patch(uri, headers: {}, body: {}, **opts)
    body = body.to_json unless body.is_a?(String)
    headers = default_headers.merge(headers)
    response = HTTParty.patch(uri, headers: headers, body: body, **opts)
    parse_response(response)
  end

  def self.delete(uri, headers: {}, **opts)
    headers = default_headers.merge(headers)
    response = HTTParty.delete(uri, headers: headers, **opts)
    parse_response(response)
  end
end

base_path = 'http://localhost:4567/api'
login_payload = { data: { type: 'sessions', attributes: { login: 'admin', password: 'password' } } }
login_code, login_resp, login_headers = JsonApiClient.post("#{base_path}/sessions", body: login_payload)

puts "Login response #{login_code}", JSON.pretty_generate(login_resp)
exit 1 if login_code != 201

cookies = login_headers['set-cookie']
cookies = cookies.join('') if cookies.is_a?(Array)
# puts "Cookie: ##{cookies}"

auth_headers = { Cookie: cookies }

query = { fields: { 'virtual-machines': 'name,state,tags' } }
resp_code, resp_body = JsonApiClient.get("#{base_path}/virtual-machines?#{query.to_query}", headers: auth_headers)
puts "Response #{resp_code}", JSON.pretty_generate(resp_body)

vm_id = resp_body[:data].first[:id]
payload = {
    data: {
        id: vm_id,
        type: 'virtual-machines',
        attributes: { tags: ['foo', Process.pid.to_s] }
    }
}
resp_code, resp_body = JsonApiClient.patch(
    "#{base_path}/virtual-machines/#{vm_id}?#{query.to_query}", body: payload, headers: auth_headers
)
puts "Response #{resp_code}", JSON.pretty_generate(resp_body)

# ws_headers = { 'Cookie': cookies }
# received = []
# closed = false
# ws = WebSocket::Client::Simple.connect 'ws://localhost:4567/api_cable', headers: ws_headers
#
# at_exit do
#   ws.close rescue nil
#   puts 'Exited.'
# end
#
# ws.on :message do |msg|
#   puts 'Websocket on message'
#   puts msg.data.inspect
#   received << msg.data
# end
#
# ws.on :open do
#   puts 'Websocket on open'
# end
#
# ws.on :close do |e|
#   puts 'Websocket on close'
#   puts e
#   # closed = true
#   exit 1
# end
#
# ws.on :error do |e|
#   puts 'Websocket on error'
#   STDERR.puts e
# end
#
# loop { ws.send STDIN.gets.strip }
#
# sleep 1
# domain_uuid = ARGV[0]
# ws_body = { type: 'screenshot', id: domain_uuid }.to_json
# puts "Websocket send #{ws_body}"
# ws.send(ws_body)
#
# puts 'Loop started'
# while !closed do
#   sleep 1
#   ws.send('{"type":"ping"}')
# end
