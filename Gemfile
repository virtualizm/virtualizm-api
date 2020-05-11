# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem 'rake'

# Utility classes and Ruby extensions.
gem 'activesupport', require: 'active_support/all'

gem 'rack', '>= 2.1.0'

# Contributed Rack Middleware and Utilities.
gem 'rack-contrib'

# Protects against typical web attacks.
gem 'rack-protection'

# Simple and functional rack middleware for routing requests.
# https://github.com/senid231/rack_router
gem 'rack_router', '>= 0.1.2'

# Async web server.
# https://github.com/socketry/falcon
gem 'falcon'

gem 'libvirt_ffi', '~> 0.5'

# Async libvirt event api implementation
# https://github.com/senid231/libvirt_async
gem 'libvirt_async', github: 'senid231/libvirt_async'

# Very simple but functional websocket server for Rack async application.
# https://github.com/seni231/async_cable
gem 'async_cable'

# Ruby libraries and applications configuration on steroids!
# https://github.com/palkan/anyway_config
gem 'anyway_config', '2.0.3'

# Efficiently produce and consume JSON API documents.
# https://github.com/jsonapi-rb/jsonapi-rb
gem 'jsonapi-rb', require: %w[jsonapi/serializable jsonapi/deserializable]

# Convert images.
# https://github.com/minimagick/minimagick
gem 'mini_magick'

gem 'nokogiri'

gem 'net-ldap'

group :development, :test do
  gem 'byebug'
  gem 'gc_tracer', require: false
  gem 'get_process_mem', require: false
  gem 'rbtrace', require: false
  gem 'rubocop', '~> 0.82.0'
end

group :test do
  gem 'minitest', require: false
  gem 'minitest-reporters', require: false
  gem 'rack-test', require: false
  # for script/client.rb
  gem 'httparty', require: false
  gem 'websocket-client-simple', require: false
end
