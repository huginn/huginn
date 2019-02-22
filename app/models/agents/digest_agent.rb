module Agents
  class DigestAgent < Agent
    include FormConfigurable

    default_schedule "6am"

    description <<-MD
      The Digest Agent collects any Events sent to it and emits them as a single event.

      The resulting Event will have a payload message of `message`. You can use liquid templating in the `message`, have a look at the [Wiki](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) for details.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.

      If `retained_events` is set to 0 (the default), all received events are cleared after a digest is sent. Set `retained_events` to a value larger than 0 to keep a certain number of events around on a rolling basis to re-send in future digests.

      For instance, say `retained_events` is set to 3 and the Agent has received Events `5`, `4`, and `3`. When a digest is sent, Events `5`, `4`, and `3` are retained for a future digest. After Event `6` is received, the next digest will contain Events `6`, `5`, and `4`.
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
          "retained_events" => "0"
      }
    end

    form_configurable :message, type: :text
    form_configurable :expected_receive_period_in_days
    form_configurable :retained_events

    def validate_options
      errors.add(:base, 'retained_events must be 0 to 999') unless options['retained_events'].to_i >= 0 && options['retained_events'].to_i < 1000
    end

    def working?
      last_receive_at && last_receive_at > interpolated["expected_receive_period_in_days"].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      self.memory["queue"] ||= []
      incoming_events.each do |event|
        self.memory["queue"] << event.id
      end
      if interpolated["retained_events"].to_i > 0 && memory["queue"].length > interpolated["retained_events"].to_i
        memory["queue"].shift(memory["queue"].length - interpolated["retained_events"].to_i)
      end
    end

    def check
      if self.memory["queue"] && self.memory["queue"].length > 0
        events = received_events.where(id: self.memory["queue"]).order(id: :asc).to_a
        payload = { "events" => events.map { |event| event.payload } }
        payload["message"] = interpolated(payload)["message"]
        create_event :payload => payload
        if interpolated["retained_events"].to_i == 0
          self.memory["queue"] = []
        end
      end
    end
  end
end
