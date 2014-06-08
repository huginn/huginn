module Agents
  class WatchdogAgent < Agent

    description <<-MD
      A WatchdogAgent emits an event if it did not receive an event for a given amount of time.
      `timespan` can be something like `10m` (10 minutes), `9.7h` (9.7 hours) or `18d` (18 days).
      If `emit_once` is set to `false`, it will emit one event for each scheduled run, until it
      receives an event again. If it is set to `true`, it will only emit one event.
      In `message` you can give a message that will be part of the emitted event.
    MD

    event_description <<-MD
      Events look like this:

          { "message": "Your message" }
    MD

    default_schedule "8pm"

    def validate_options
      log options['timespan']
      unless options['timespan'].present? && ('mhd'.include? options['timespan'][-1]) && options['timespan'][0..-2].to_f > 0
        errors.add(:base, "timespan is required and has to be a positive number followed by 'm', 'h' or 'd'")
      end
      errors.add(:base, "message is required") unless options['message'].present?
    end

    def default_options
      {
        'timespan' => "5.2d",
        'message' => "Nothing happened in the last 5.2 days!",
        'emit_once' => "true"
      }
    end

    def working?
      !recent_error_logs?
    end

    def check
      unless options['emit_once'].to_s == 'true' && !received_after_last_emit?
        timeout = (options['timespan'][0..-2].to_f * (case options['timespan'][-1]
          when 'm' then 60
          when 'h' then (60 * 60)
          when 'd' then (60 * 60 * 25)
          else 1
        end)).seconds.ago
        if last_receive_at < timeout
          received_after_last_emit false
          create_event :payload => {'message' => options['message'] }
        end
      end
    end

    def receive(events)
      received_after_last_emit true
    end

    def received_after_last_emit?
      memory['received after last emit'].to_s == 'true'
    end

    def received_after_last_emit(value)
      memory['received after last emit'] = (value.to_s == 'true')
    end
  end
end
