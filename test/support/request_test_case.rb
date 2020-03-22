# frozen_string_literal: true

require_relative 'within_async_reactor'
require_relative 'within_cache_methods'

class RequestTestCase < Minitest::Test
  include Rack::Test::Methods
  include WithinAsyncReactor
  include WithCacheMethods

  def app
    Application.app
  end

  private

  def get_json_api(url, params = {})
    header 'Accept', JSONAPI::Const::MIME_TYPE
    get url, params
  end

  def post_json_api(url, params = {})
    header 'Accept', JSONAPI::Const::MIME_TYPE
    header 'Content-Type', JSONAPI::Const::MIME_TYPE
    post url, params
  end

  def put_json_api(url, params = {})
    header 'Accept', JSONAPI::Const::MIME_TYPE
    header 'Content-Type', JSONAPI::Const::MIME_TYPE
    put url, params
  end

  def patch_json_api(url, params = {})
    header 'Accept', JSONAPI::Const::MIME_TYPE
    header 'Content-Type', JSONAPI::Const::MIME_TYPE
    patch url, params
  end

  def delete_json_api(url, params = {})
    header 'Accept', JSONAPI::Const::MIME_TYPE
    delete url, params
  end

  def assert_response_headers(expected_headers)
    actual_headers = last_response.headers.transform_keys { |k| k.downcase.to_sym }
    failure_msg = proc { "Expected headers #{expected_headers}, but got #{actual_headers}\n#{last_response.body}" }
    expected = expected_headers.transform_keys { |k| k.to_s.downcase.to_sym }
    actual = actual_headers.slice(*expected_headers.keys)
    assert_equal expected, actual, failure_msg
  end

  def assert_http_status(expected_status)
    failure_msg = proc { "Expected response status to be #{expected_status}, but got #{last_response.status}\n#{last_response_json || last_response.body}" }
    assert_equal expected_status, last_response.status, failure_msg
  end

  # @param expected_body [String]
  def assert_response_body(expected_body)
    failure_msg = proc { "Expected body to be #{expected_body.inspect}, but got #{last_response.body.inspect}" }
    assert_equal expected_body, last_response.body, failure_msg
  end

  # @param expected_body [Hash]
  def assert_json_body(expected_body)
    failure_msg = proc { "Expected json body to be #{expected_body.inspect}, but got #{last_response_json.inspect}" }
    assert_equal expected_body, last_response_json, failure_msg
  end

  define_cache(:last_response_json) do
    JSON.parse(last_response.body, symbolize_names: true)
  rescue JSON::ParserError => e
    # \u21B3 - DOWNWARDS ARROW WITH TIP RIGHTWARDS
    bt = caller[3..5].map { |l| " \u21B3 #{l}" }.join("\n")
    warn "last_response_json ParserError #{e.message}\n#{bt}"
    nil
  end

  # Set cookie for next request.
  # @param raw_cookie [String]
  def set_cookie_header(raw_cookie)
    header 'Cookie', raw_cookie
  end

  # Performs sign in request and return cookie.
  # @return [String] raw cookie
  def sign_in_for_cookie(user)
    post_json_api '/api/sessions', {
        data: {
            type: 'sessions',
            attributes: {
                login: user.login,
                password: user.password
            }
        }
    }.to_json
    last_response.headers['Set-Cookie']
  end
end
