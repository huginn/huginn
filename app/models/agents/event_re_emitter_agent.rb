module Agents
  class EventReEmitterAgent < Agent

    default_schedule "1d"

    description <<-MD
      The Event Re-Emitter Agent is very simple - it will re-emit any events in it's memory on the given schedule.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def default_options
      {
          'expected_receive_period_in_days' => "2"
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        self.memory['events'] ||= []
        self.memory['events'] << event.payload

        # the rest of the app doesn't like sets, so we just go back to an array after converting to set to uniqueify
        self.memory['events'] = self.memory['events'].to_set.to_a
      end
    end

    def check
      if self.memory['events'] && self.memory['events'].length > 0
        self.memory['events'].each do |event_payload|
          log "Re-emitting event [#{event_payload}]"
          create_event :payload => event_payload
        end
      end
    end
  end
end