require 'googleauth'
require 'google/apis/calendar_v3'
require 'json'
require 'stringio'

class GoogleCalendar
  def initialize(config, logger)
    @logger = logger
    @authorization = service_account_credentials(config['google'])
    @calendar = Google::Apis::CalendarV3::CalendarService.new
  end

  def auth_as
    @authorization.fetch_access_token!
    @calendar.authorization = @authorization
  end

  # who - String: email of user to add event
  # details - JSON String: see https://developers.google.com/google-apps/calendar/v3/reference/events/insert
  def publish_as(who, details)
    auth_as

    @logger.info("Attempting to create event for " + who)
    @logger.debug details.to_yaml

    event = Google::Apis::CalendarV3::Event.new(**details.deep_symbolize_keys)
    ret = @calendar.insert_event(
        who,
        event,
        send_notifications: true
      )

    @logger.debug ret.to_yaml
    ret.to_h
  end

  def events_as(who, date)
    auth_as

    date ||= Date.today

    @logger.info("Attempting to receive events for "+who)
    @logger.debug details.to_yaml

    ret = @calendar.list_events(
        who
      )

    @logger.debug ret.to_yaml
    ret.to_h
  end

  private

  def service_account_credentials(google_options)
    unless google_options.is_a?(Hash)
      raise ArgumentError, "Google Calendar requires agent service account credentials"
    end

    scope = Google::Apis::CalendarV3::AUTH_CALENDAR
    if (key = google_options['key']).present?
      email = google_options['service_account_email']
      unless key.is_a?(String) && email.is_a?(String) && email.present?
        raise ArgumentError, "Google Calendar requires a private key and service account email"
      end

      json = JSON.generate(
        type: 'service_account',
        client_email: email,
        private_key: Google::Auth::ServiceAccountCredentials.unescape(key)
      )
      Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: StringIO.new(json), scope:)
    elsif (path = google_options['key_file']).is_a?(String) && path.present?
      unless ENV['ENABLE_INSECURE_AGENTS'] == 'true'
        raise ArgumentError, "Google Calendar key_file is disabled. Set key and service_account_email instead."
      end

      File.open(path, 'r') do |file|
        Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: file, scope:)
      end
    else
      raise ArgumentError, "Google Calendar requires agent service account credentials"
    end
  end
end
