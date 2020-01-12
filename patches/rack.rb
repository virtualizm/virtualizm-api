Rack::Response.class_eval do
  def finish(&block)
    if Rack::Response::STATUS_WITH_NO_ENTITY_BODY[status.to_i] && status.to_i != 101
      delete_header Rack::CONTENT_TYPE
      delete_header Rack::CONTENT_LENGTH
      close
      [status.to_i, header, []]
    else
      if block_given?
        @block = block
        [status.to_i, header, self]
      else
        [status.to_i, header, @body]
      end
    end
  end
end
