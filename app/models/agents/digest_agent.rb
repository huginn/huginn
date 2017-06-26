module Agents
  class DigestAgent < Agent
    include FormConfigurable

    default_schedule "6am"

    description <<-MD
      The Digest Agent collects any Events sent to it and emits them as a single event.

      The resulting Event will have a payload message of `message`. You can use liquid templating in the `message`, have a look at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) for details.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.

      If `clear_queue` is set to 0, Events are automatically purged from the memory when an Event is emitted by this Agent. To maintain a fixed number of Events, set `clear_queue` to that number.
    MD

    event_description <<-MD
      Events look like this:

          {
            "events": [ event list ],
            "message": "Your message"
          }
    MD

    def default_options
      {
          "expected_receive_period_in_days" => "2",
          "message" => "{{ events | map: 'message' | join: ',' }}",
          "clear_queue" => "0"
      }
    end

    form_configurable :message, type: :text
    form_configurable :expected_receive_period_in_days
    form_configurable :clear_queue

    def validate_options
      errors.add(:base, 'clear_queue must be 0 to 999') unless options['clear_queue'].to_i >= 0 && options['clear_queue'].to_i < 1000
    end

    def working?
      last_receive_at && last_receive_at > interpolated["expected_receive_period_in_days"].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      self.memory["queue"] ||= []
      incoming_events.each do |event|
        self.memory["queue"] << event.id
      end
      if interpolated["clear_queue"].to_i > 0
        while self.memory["queue"].length > interpolated["clear_queue"].to_i do
          self.memory["queue"].shift
        end
      end
    end

    def check
      if self.memory["queue"] && self.memory["queue"].length > 0
        events = received_events.where(id: self.memory["queue"]).order(id: :asc).to_a
        payload = { "events" => events.map { |event| event.payload } }
        payload["message"] = interpolated(payload)["message"]
        create_event :payload => payload
        if interpolated["clear_queue"].to_i == 0
          self.memory["queue"] = []
        end
      end
    end
  end
end
