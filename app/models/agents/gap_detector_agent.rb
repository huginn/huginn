module Agents
  class GapDetectorAgent < Agent
    default_schedule "every_10m"

    description <<-MD
      The Gap Detector Agent will watch for holes or gaps in a stream of incoming Events and generate "no data alerts".

      The `value_path` value is a [JSONPath](http://goessner.net/articles/JsonPath/) to a value of interest. If either
      this value is empty, or no Events are received, during `window_duration_in_days`, an Event will be created with
      a payload of `message`.

      The `stream_path` value is a [JSONPath](http://goessner.net/articles/JsonPath/) to a value in the event that will
      be used to as a stream differentiator.  If `stream_path` is set to "color" and your event has a "color" in the
      payload, this agent will watch for a gap in the stream for each value of color that has been seen.
    MD

    event_description <<-MD
      Events look like:

          {
            "message": "No data has been received!",
            "gap_started_at": "1234567890"
          }
    MD

    def validate_options
      unless options['message'].present?
        errors.add(:base, "message is required")
      end

      unless options['window_duration_in_days'].present? && options['window_duration_in_days'].to_f > 0
        errors.add(:base, "window_duration_in_days must be provided as an integer or floating point number")
      end
    end

    def default_options
      {
        'window_duration_in_days' => "2",
        'message' => "No data has been received!"
      }
    end

    def working?
      true
    end

    def receive(incoming_events)
      incoming_events.sort_by(&:created_at).each do |event|
        if !interpolated['value_path'].present? || Utils.value_at(event.payload, interpolated['value_path']).present?
          if stream_path
            @stream = Utils.value_at(event.payload, stream_path)
            next unless @stream
          end
          if event.created_at.to_i > newest_event_created_at
            self.newest_event_created_at = event.created_at.to_i
            clear_alerted_at
          end
        end
      end
    end

    def check
      window = interpolated['window_duration_in_days'].to_f.days.ago
      if stream_path
        memory.each_key do |stream|
          next unless memory[stream].is_a? Hash
          next unless memory[stream].has_key? 'newest_event_created_at'
          @stream = stream
          check_stream(window)
        end
      else
        check_stream(window)
      end
    end

    private

    def check_stream(window)
      window = interpolated['window_duration_in_days'].to_f.days.ago
      if newest_event_created_at? && Time.at(newest_event_created_at) < window
        unless alerted_at
          self.alerted_at = Time.now.to_i
          event_payload = { message: interpolated['message'],
                            gap_started_at: newest_event_created_at }
          event_payload.merge!({ stream_path => @stream }) if stream_path
          create_event payload: event_payload
        end
      end
    end

    def newest_event_created_at?
      event_storage['newest_event_created_at'].present?
    end

    def newest_event_created_at
      event_storage['newest_event_created_at'] || 0
    end

    def newest_event_created_at=(value)
      event_storage['newest_event_created_at'] = value
    end

    def alerted_at
      event_storage['alerted_at']
    end

    def alerted_at=(value)
      event_storage['alerted_at'] = value
    end

    def clear_alerted_at
      event_storage.delete('alerted_at')
    end

    def event_storage
      return memory unless @stream_path
      memory[@stream] = {} unless memory.has_key?(@stream)
      memory[@stream]
    end

    def stream_path
      @stream_path ||= interpolated['stream_path']
    end

  end
end
