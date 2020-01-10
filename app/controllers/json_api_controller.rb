require_relative 'base_controller'

class JsonApiController < BaseController
  rescue_from StandardError, with: :json_api_exception

  class_attribute :renderer, instance_writer: false, default: JSONAPI::Serializable::Renderer.new
  class_attribute :resource_class, instance_writer: false

  def index
    json_api_verify_env!
    options = json_api_options
    objects = resource_class.find_collection(options)
    body = json_api_response_body(objects, resource_class, options)
    response_json_api status: 200, body: body
  end

  def show
    json_api_verify_env!
    options = json_api_options
    object = resource_class.find_single(path_params[:id], options)
    body = json_api_response_body(object, resource_class, options)
    response_json_api status: 200, body: body
  end

  def create
    json_api_verify_env!
    options = json_api_options
    payload = json_api_body
    data = resource_class::Deserializable.call(payload[:data]&.deep_stringify_keys || {})
    object = resource_class.create(data, options)
    body = json_api_response_body(object, resource_class, options)
    response_json_api status: 201, body: body
  end

  def update
    json_api_verify_env!
    options = json_api_options
    object = resource_class.find_single(path_params[:id], options)
    object.destroy
    body = json_api_response_body(object, resource_class, options)
    response_json_api status: 200, body: body
  end

  def destroy
    json_api_verify_env!
    options = json_api_options
    object = resource_class.find_single(path_params[:id], options)
    resource_class.destroy(object, options)
    response_json_api status: 204
  end

  private

  def authenticate_current_user!
    raise JSONAPI::Errors::UnauthorizedError if current_user.nil?
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = User.find_by id: session['user_id']
  end

  def json_api_response_body(object, klass, options)
    expose = { context: options[:context] }
    includes = options[:includes]
    fields = options[:fields] || {}

    renderer.render(
        object,
        jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
        class: klass.render_classes,
        expose: expose,
        fields: fields,
        include: includes
    )
  end

  def json_api_context
    { request: request }
  end

  def json_api_options
    {
        context: json_api_context,
        filters: request.params[:filter] || {},
        includes: request.params[:include].to_s.split(','),
        fields: (request.params[:field] || {}).transform_values { |v| v.split(',') }
    }
    # todo verify options
  end

  def json_api_exception(e)
    unless e.is_a?(JSONAPI::Errors::Error)
      log_error(e)
      e = JSONAPI::Errors::ServerError.new
    end
    body = renderer.render_errors(
        [e],
        jsonapi: { version: JSONAPI::Const::SPEC_VERSION },
        class: e.render_classes,
        expose: e.render_expose
    )
    response_json_api(status: e.status, body: body)
  end

  def response_json_api(status: 200, headers: {}, body: nil)
    headers = headers.merge(Rack::CONTENT_TYPE => JSONAPI::Const::MIME_TYPE)
    body = body.to_json if body.is_a?(Hash)
    [status, headers, [body]]
  end

  def json_api_verify_env!
    accepts = env['HTTP_ACCEPT'].to_s.split(';').first&.split(',') || []
    raise JSONAPI::Errors::BadRequest, 'Wrong Accept header' unless accepts.include?(JSONAPI::Const::MIME_TYPE)
    if request.post? || request.put? || request.patch?
      content_type = request.content_type
      raise JSONAPI::Errors::BadRequest, 'Wrong Content-Type header' if content_type != JSONAPI::Const::MIME_TYPE
    end
  end

  def json_api_body
    JSON.parse(request.body.read, symbolize_names: true)
  end
end
