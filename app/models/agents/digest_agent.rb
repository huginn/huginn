module Agents
  class DigestAgent < Agent
    include FormConfigurable

    default_schedule "6am"

    description <<-MD
      The Digest Agent collects any Events sent to it and emits them as a single event.

      The resulting Event will have a payload message of `message`. You can use liquid templating in the `message`, have a look at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) for details.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
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
          "message" => "{{ events | map: 'message' | join: ',' }}"
      }
    end

    form_configurable :message, type: :text
    form_configurable :expected_receive_period_in_days

    def working?
      last_receive_at && last_receive_at > interpolated["expected_receive_period_in_days"].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      self.memory["queue"] ||= []
      incoming_events.each do |event|
        self.memory["queue"] << event.id
      end
    end

    def check
      if self.memory["queue"] && self.memory["queue"].length > 0
        events = received_events.where(id: self.memory["queue"]).order(id: :asc).to_a
        payload = { "events" => events.map { |event| event.payload } }
        payload["message"] = interpolated(payload)["message"]
        create_event :payload => payload
        self.memory["queue"] = []
      end
    end
  end
end
