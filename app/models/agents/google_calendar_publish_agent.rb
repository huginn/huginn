require 'json'
require 'google/apis/calendar_v3'

module Agents
  class GoogleCalendarPublishAgent < Agent
    cannot_be_scheduled!
    no_bulk_receive!

    gem_dependency_check { defined?(Google) && defined?(Google::Apis::CalendarV3) }

    description <<-MD
      The Google Calendar Publish Agent creates events on your Google Calendar.

      #{'## Include `google-api-client` in your Gemfile to use this Agent!' if dependencies_missing?}

      This agent relies on service accounts, rather than oauth.

      Setup:

      1. Visit [the google api console](https://code.google.com/apis/console/b/0/)
      2. New project -> Huginn
      3. APIs & Auth -> Enable google calendar
      4. Credentials -> Create new Client ID -> Service Account
      5. Download the JSON keyfile and save it to a path, ie: `/home/huginn/Huginn-5d12345678cd.json`. Or open that file and copy the `private_key`.
      6. Grant access via google calendar UI to the service account email address for each calendar you wish to manage. For a whole google apps domain, you can [delegate authority](https://developers.google.com/+/domains/authentication/delegation)

      An earlier version of Huginn used PKCS12 key files to authenticate. This will no longer work, you should generate a new JSON format keyfile, that will look something like:
      <pre><code>{
        "type": "service_account",
        "project_id": "huginn-123123",
        "private_key_id": "6d6b476fc6ccdb31e0f171991e5528bb396ffbe4",
        "private_key": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n",
        "client_email": "huginn-calendar@huginn-123123.iam.gserviceaccount.com",
        "client_id": "123123...123123",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://accounts.google.com/o/oauth2/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/huginn-calendar%40huginn-123123.iam.gserviceaccount.com"
      }</code></pre>


      Agent Configuration:

      `calendar_id` - The id the calendar you want to publish to. Typically your google account email address.  Liquid formatting (e.g. `{{ cal_id }}`) is allowed here in order to extract the calendar_id from the incoming event.

      `google` A hash of configuration options for the agent.

      `google` `service_account_email` - The authorised service account email address.

      `google` `key_file` OR `google` `key` - The path to the JSON key file above, or the key itself (the value of `private_key`).  [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) formatting is supported if you want to use a Credential.  (E.g., `{% credential google_key %}`)

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Use it with a trigger agent to shape your payload!

      A hash of event details. See the [Google Calendar API docs](https://developers.google.com/google-apps/calendar/v3/reference/events/insert)

      The prior version Google's API expected keys like `dateTime` but in the latest version they expect snake case keys like `date_time`.

      Example payload for trigger agent:
      <pre><code>{
        "message": {
          "visibility": "default",
          "summary": "Awesome event",
          "description": "An example event with text. Pro tip: DateTimes are in RFC3339",
          "start": {
            "date_time": "2017-06-30T17:00:00-05:00"
          },
          "end": {
            "date_time": "2017-06-30T18:00:00-05:00"
          }
        }
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
          'key' => '-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n',
          'service_account_email' => ''
        }
      }
    end

    def receive(incoming_events)
      require 'google_calendar'
      incoming_events.each do |event|
        GoogleCalendar.open(interpolate_options(options, event), Rails.logger) do |calendar|

          cal_message = event.payload["message"]
          if cal_message["start"].present? && cal_message["start"]["dateTime"].present? && !cal_message["start"]["date_time"].present?
            cal_message["start"]["date_time"] = cal_message["start"].delete "dateTime"
          end
          if cal_message["end"].present? && cal_message["end"]["dateTime"].present? && !cal_message["end"]["date_time"].present?
            cal_message["end"]["date_time"] = cal_message["end"].delete "dateTime"
          end

          calendar_event = calendar.publish_as(
                interpolated(event)['calendar_id'],
                cal_message
              )

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
end

