module Agents
  class GoogleCalendarPublishAgent < Agent
    include LiquidInterpolatable

    cannot_be_scheduled!

    description <<-MD
      The GoogleCalendarPublishAgent creates events on your google calendar.

      This agent relies on service accounts, rather than oauth.

      Setup:

      1) Visit https://code.google.com/apis/console/b/0/

      2) New project -> Huginn
 
      3) APIs & Auth -> Enable google calendar

      4) Credentials -> Create new Client ID -> Service Account

      5) Persist the generated private key to a path, ie: /home/hugin/a822ccdefac89fac6330f95039c492dfa3ce6843.p12

      6) Grant access via google calendar UI to the service account email address for each calendar you wish to manage. For a whole google apps domain, you can delegate authority (https://developers.google.com/+/domains/authentication/delegation)


      Agent Configuration:

      `calendar_id` - The id the calendar you want to publish to. Typically your google account email address.

      `service_account_email` - The authorised service account.

      `key_file` - The path to the key file.

      `key_secret` - The secret for the key, typically 'notasecret'
      

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
        'calendar_id' => 'you@email.com',
        'message' => "{{text}}",
        'google' => {
          'key_file' => '/path/to/private.key'
          'key_secret' => 'notasecret',
          'service_account_email' => ''
        }
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

