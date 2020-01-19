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

# https://bugzilla.redhat.com/show_bug.cgi?id=1787914
# Use patched version of gem until issue resolved.
#   $ gem install ./ruby-libvirt-0.7.2.pre.streamfix.gem
#   $ bundle install
#
gem 'ruby-libvirt', '0.7.2.pre.streamfix3.2', require: 'libvirt'

# Async libvirt event api implementation
# https://github.com/senid231/libvirt_async
gem 'libvirt_async', '~> 0.1'

# Very simple but functional websocket server for Rack async application.
# https://github.com/seni231/async_cable
gem 'async_cable'

# Ruby libraries and applications configuration on steroids!
# https://github.com/palkan/anyway_config
gem 'anyway_config', '2.0.0.pre'

# Efficiently produce and consume JSON API documents.
# https://github.com/jsonapi-rb/jsonapi-rb
gem 'jsonapi-rb', require: %w(jsonapi/serializable jsonapi/deserializable)

# Convert images.
# https://github.com/minimagick/minimagick
gem 'mini_magick'

group :development, :test do
  gem 'byebug'
  gem 'rbtrace', require: false
  gem 'get_process_mem', require: false
  gem 'gc_tracer', require: false
end

group :test do
  gem 'minitest', require: false
  gem 'rack-test', require: false
  gem 'minitest-reporters', require: false
  # for script/client.rb
  gem 'httparty', require: false
  gem 'websocket-client-simple', require: false
end
