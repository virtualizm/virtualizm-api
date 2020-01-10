require_relative '../test_helper'

class TestSessionsCreate < RequestTestCase
  def setup
  end

  def test_post_sessions
    user = User.all.first
    post_json_api '/api/sessions', {
        data: {
            type: 'sessions',
            attributes: {
                login: user.login,
                password: user.password
            }
        }
    }.to_json
    assert_http_status 201
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: 'sessions',
                         type: 'sessions',
                         attributes: {
                             login: user.login
                         }
                     }
    assert last_response.headers['Set-Cookie'].present?
  end
end
