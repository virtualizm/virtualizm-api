ENV['RACK_ENV'] ||= 'development'

require_relative 'app'

run LibvirtApp.app
