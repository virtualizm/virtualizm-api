# frozen_string_literal: true

module TrackTime
  mattr_accessor :storage, instance_writer: false, default: {}
  mattr_accessor :_last_track, instance_writer: false, default: nil

  def start_track(*keys)
    combined_key = keys.map(&method(:object_to_key))
    raise ArgumentError, "keys already exist" if storage.key?(combined_key)
    storage[combined_key] = Time.now.to_f
    nil
  end

  # @return [Float] ms
  def end_track(*keys)
    t2 = Time.now.to_f
    combined_key = keys.map(&method(:object_to_key))
    raise ArgumentError, "keys already exist" unless storage.key?(combined_key)
    t1 = storage.delete(combined_key)
    (t2 - t1) * 1_000
  end

  # @return yield result
  def track
    raise ArgumentError, 'block required' unless block_given?
    raise ArgumentError, 'last_track not cleared' unless _last_track.nil?

    t1 = Time.now.to_f
    result = yield
    raise ArgumentError, 'last_track not cleared inside' unless _last_track.nil?
    t2 = Time.now.to_f
    self._last_track = t2 - t1
    result
  end

  # @return [Float] ms
  def last_track
    result = _last_track
    self._last_track = nil
    result * 1_000
  end

  def object_to_key(key)
    return key if key.is_a?(String)
    "#{key.class}:0x#{key.object_id.to_s(16)}"
  end

  module_function :start_track,
                  :end_track,
                  :track,
                  :last_track,
                  :object_to_key
end
