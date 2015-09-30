require 'json'

module Agents
  class GoogleCalendarPublishAgent < Agent
    cannot_be_scheduled!

    gem_dependency_check { defined?(Google) && defined?(Google::APIClient) }

    description <<-MD
      The Google Calendar Publish Agent creates events on your Google Calendar.

      #{'## Include `google-api-client` in your Gemfile to use this Agent!' if dependencies_missing?}

      This agent relies on service accounts, rather than oauth.

      Setup:

      1. Visit [the google api console](https://code.google.com/apis/console/b/0/)
      2. New project -> Huginn
      3. APIs & Auth -> Enable google calendar
      4. Credentials -> Create new Client ID -> Service Account
      5. Persist the generated private key to a path, ie: `/home/huginn/a822ccdefac89fac6330f95039c492dfa3ce6843.p12`
      6. Grant access via google calendar UI to the service account email address for each calendar you wish to manage. For a whole google apps domain, you can [delegate authority](https://developers.google.com/+/domains/authentication/delegation)


      Agent Configuration:

      `calendar_id` - The id the calendar you want to publish to. Typically your google account email address.

      `google` A hash of configuration options for the agent.

      `google` `service_account_email` - The authorised service account.

      `google` `key_file` - The path to the key file.

      `google` `key_secret` - The secret for the key, typically 'notasecret'

      

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Use it with a trigger agent to shape your payload!

      By default, publish using the `insert` method which requires a hash of event details. See the [Google Calendar API docs](https://developers.google.com/google-apps/calendar/v3/reference/events/insert)

      Example payload for trigger agent:
      <pre><code>{
        "message": {
          "visibility": "default",
          "summary": "Awesome event",
          "description": "An example event with text. Pro tip: DateTimes are in RFC3339",
          "start": {
            "dateTime": "2014-10-02T10:00:00-05:00"
          },
          "end": {
            "dateTime": "2014-10-02T11:00:00-05:00"
          }
        }
      }</code></pre>

      Alternatively, set the `method` parameter to `quickadd` to use the `quickadd` method, which takes a text string describing what, where, and when.  See the [Google Calendar API docs](https://developers.google.com/google-apps/calendar/v3/reference/events/insert) and [Quick Add synax](https://support.google.com/calendar/answer/36604?hl=en)

      Example payload for trigger agent:
      <pre><code>{
        "method": "quickadd",
        "message": "Brunch with Mom at Java 11am Sunday"
      }</code></pre>

    MD

    event_description <<-MD
      {
        'success' => true,
        'published_calendar_event' => {
           ....
        },
        'agent_id' => 1234,
        'event_id' => 3432
      }
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
        'google' => {
          'key_file' => '/path/to/private.key',
          'key_secret' => 'notasecret',
          'service_account_email' => ''
        }
      }
    end

    def receive(incoming_events)
     incoming_events.each do |event|
        calendar = GoogleCalendar.new(options, Rails.logger)

        # publish using quickadd or insert; default insert
        if event.payload["method"] == "quickadd" || interpolated["method"] == "quickadd"
          log "publish - quickadd "+event.payload["message"]
          response = calendar.quickadd_as(options['calendar_id'], event.payload["message"])
        else
          log "publish - insert "+event.payload["message"] 
          response = calendar.publish_as(options['calendar_id'], event.payload["message"])
        end
        calendar_event = JSON.parse(response.response.body)
        create_event :payload => {
          'success' => true,
          'published_calendar_event' => calendar_event,
          'agent_id' => event.agent_id,
          'event_id' => event.id
        }
      end
    end
  end
end

