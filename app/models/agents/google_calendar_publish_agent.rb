module Agents
  class GoogleCalendarPublishAgent < Agent
    include LiquidInterpolatable

    cannot_be_scheduled!

    description <<-MD
      The GoogleCalendarPublishAgent creates events on your google calendar.



      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => "10",
        'calendar_id' => '?',
        'message' => "{{text}}"
      }
    end

    def receive(incoming_events)
     incoming_events.each do |event|
        text = interpolate_string(options['message'], event.payload)
        calendar_event = publish text

        create_event :payload => {
          'success' => true,
          'published_calendar_event' => text,
          'tweet_id' => calendar_event.id,
          'agent_id' => event.agent_id,
          'event_id' => event.id
        }
      end
    end

    def publish(text)
      calendar = GoogleCalendar.new(options, Rails.logger)

      calender.publish_as(options['calendar_id'], text)
    end
  end
end

