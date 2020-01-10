require 'falcon/adapters/output'

Falcon::Adapters::Output.class_eval do
  def call(stream)
    @body.call(stream)
  end
end
