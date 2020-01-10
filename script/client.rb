begin
  require 'bundler/inline'
  require 'bundler'
rescue LoadError => e
  STDERR.puts 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

gemfile(true, ui: Bundler::UI::Silent.new) do
  source 'https://rubygems.org'

  gem 'httparty'
  gem 'websocket-client-simple'
end

require 'httparty'

json_api_mime_type = 'application/vnd.api+json'
json_api_headers = { 'Accept': json_api_mime_type, 'Content-Type': json_api_mime_type }
login_body = { data: { type: 'sessions', attributes: { login: 'admin', password: 'password' } } }.to_json
response = HTTParty.post('http://localhost:4567/api/sessions', body: login_body, headers: json_api_headers)

puts "Response: #{response.code}\n#{response}"
if response.code != 201
  exit 1
end

cookies = response.headers['set-cookie']
cookies = cookies.join('') if cookies.is_a?(Array)
puts "Cookie: ##{cookies}"

ws_headers = { 'Cookie': cookies }
received = []
closed = false
ws = WebSocket::Client::Simple.connect 'ws://localhost:4567/cable', headers: ws_headers

at_exit do
  ws.close rescue nil
  puts 'Exited.'
end

ws.on :message do |msg|
  puts 'Websocket on message'
  puts msg.data.inspect
  received << msg.data
end

ws.on :open do
  puts 'Websocket on open'
end

ws.on :close do |e|
  puts 'Websocket on close'
  puts e
  closed = true
  exit 1
end

ws.on :error do |e|
  puts 'Websocket on error'
  STDERR.puts e
end

# loop { ws.send STDIN.gets.strip }

sleep 1
domain_uuid = ARGV[0]
ws_body = { type: 'screenshot', id: domain_uuid }.to_json
puts "Websocket send #{ws_body}"
ws.send(ws_body)

puts 'Loop started'
while !closed do
  sleep 1
  ws.send('{"type":"ping"}')
end
