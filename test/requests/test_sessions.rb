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

  def test_post_sessions_wrong_password
    user = User.all.first
    post_json_api '/api/sessions', {
        data: {
            type: 'sessions',
            attributes: {
                login: user.login,
                password: user.password + '1'
            }
        }
    }.to_json
    assert_http_status 422
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '422',
                         title: 'login or password invalid',
                         detail: 'login or password invalid'
                     ]
    assert last_response.headers['Set-Cookie'].present?
  end

  def test_get_sessions_no_cookie
    get_json_api '/api/sessions'
    assert_http_status 404
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '404',
                         title: 'id session not found',
                         detail: 'id session not found'
                     ]
  end

  def test_get_sessions_with_valid_cookie
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie
    get_json_api '/api/sessions'
    assert_http_status 200
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     data: {
                         id: 'sessions',
                         type: 'sessions',
                         attributes: {
                             login: user.login
                         }
                     }
  end

  def test_get_sessions_invalid_cookie
    set_cookie_header 'invalid-cookie'
    get_json_api '/api/sessions'
    assert_http_status 404
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '404',
                         title: 'id session not found',
                         detail: 'id session not found'
                     ]
  end

  def test_delete_sessions_no_cookie
    delete_json_api '/api/sessions'
    assert_http_status 404
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '404',
                         title: 'id session not found',
                         detail: 'id session not found'
                     ]
  end

  def test_delete_sessions_invalid_cookie
    set_cookie_header 'invalid-cookie'
    delete_json_api '/api/sessions'
    assert_http_status 404
    assert_json_body jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
                     errors: [
                         status: '404',
                         title: 'id session not found',
                         detail: 'id session not found'
                     ]
  end

  def test_delete_sessions_with_valid_cookie
    user = User.all.first
    raw_cookie = sign_in_for_cookie(user)
    set_cookie_header raw_cookie
    delete_json_api '/api/sessions'
    assert_http_status 204
    assert_equal '', last_response.body
  end
end
