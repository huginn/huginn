module Agents
  class EventReEmitterAgent < Agent

    default_schedule "every_1d"

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
        create_event :payload => event.payload
      end
    end

    def check
      if self.events && self.events.length > 0
        # Get payloads and clear events
        event_payloads = [].to_set
        self.events.each do |event|
          event_payloads << event.payload
          event.destroy!
        end

        # Migration from old memory method
        if self.memory['events'] && self.memory['events'].length > 0
          self.memory['events'].each do |mem_event|
            event_payloads << mem_event
          end

          self.memory['events'] = []
        end

        # Re create and emit events from stored payloads
        event_payloads.each do |event|
          log "Re-emitting event [#{event}]"
          create_event :payload => event
        end
      end
    end
  end
end