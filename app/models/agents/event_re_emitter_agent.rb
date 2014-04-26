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
        self.memory['queue'] ||= []
        self.memory['queue'] << event.payload
        self.memory['events'] ||= []
        self.memory['events'] << event.id
      end
    end

    def check
      if self.memory['queue'] && self.memory['queue'].length > 0
        ids = self.memory['events'].join(",")
        log "Re-emitting events [#{ids}]"
        self.memory['queue'].each do |event_payload|
          create_event :payload => event_payload
        end
      end
    end
  end
end