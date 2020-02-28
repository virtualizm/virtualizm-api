# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'development'

require_relative 'app'

run Application.app
