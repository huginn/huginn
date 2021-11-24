require 'googleauth'
require 'google/apis/calendar_v3'

class GoogleCalendar
  def initialize(config, logger)
    @config = config

    if @config['google']['key'].present?
      # https://github.com/google/google-auth-library-ruby/issues/65
      # https://github.com/google/google-api-ruby-client/issues/370
      ENV['GOOGLE_PRIVATE_KEY'] = @config['google']['key']
      ENV['GOOGLE_CLIENT_EMAIL'] = @config['google']['service_account_email']
      ENV['GOOGLE_ACCOUNT_TYPE'] = 'service_account'
    elsif @config['google']['key_file'].present?
      ENV['GOOGLE_APPLICATION_CREDENTIALS'] = @config['google']['key_file']
    end

    @logger ||= logger

    # https://github.com/google/google-api-ruby-client/blob/master/MIGRATING.md
    @calendar = Google::Apis::CalendarV3::CalendarService.new

    # https://developers.google.com/api-client-library/ruby/auth/service-accounts
    # https://developers.google.com/identity/protocols/application-default-credentials
    scopes = [Google::Apis::CalendarV3::AUTH_CALENDAR]
    @authorization = Google::Auth.get_application_default(scopes)

    @logger.info("Setup")
    @logger.debug @calendar.inspect
  end

  def self.open(*args, &block)
    instance = new(*args)
    block.call(instance)
  ensure
    instance&.cleanup!
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

    event = Google::Apis::CalendarV3::Event.new(details.deep_symbolize_keys)
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

  def cleanup!
    ENV.delete('GOOGLE_PRIVATE_KEY')
    ENV.delete('GOOGLE_CLIENT_EMAIL')
    ENV.delete('GOOGLE_ACCOUNT_TYPE')
    ENV.delete('GOOGLE_APPLICATION_CREDENTIALS')
  end
end
