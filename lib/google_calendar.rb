class GoogleCalendar
  def initialize(config, logger)
    @config = config

    if @config['google']['key'].present?
      @key = OpenSSL::PKCS12.new(@config['google']['key'], @config['google']['key_secret']).key
    else
      @key = Google::APIClient::PKCS12.load_key(@config['google']['key_file'], @config['google']['key_secret'])
    end

    @client = Google::APIClient.new(application_name: "Huginn", application_version: "0.0.1")
    @client.retries = 2
    @logger ||= logger

    @calendar = @client.discovered_api('calendar','v3')

    @logger.info("Setup")
    @logger.debug @calendar.inspect
  end

  def auth_as
    @client.authorization = Signet::OAuth2::Client.new({
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      audience:             'https://accounts.google.com/o/oauth2/token',
      scope:                'https://www.googleapis.com/auth/calendar',
      issuer:               @config['google']['service_account_email'],
      signing_key:          @key
    });

    @client.authorization.fetch_access_token!
  end

  # who - String: email of user to add event
  # details - JSON String: see https://developers.google.com/google-apps/calendar/v3/reference/events/insert
  def publish_as(who, details)
    auth_as

    @logger.info("Attempting to create event for " + who)
    @logger.debug details.to_yaml

    ret = @client.execute(
      api_method: @calendar.events.insert,
      parameters: {'calendarId' => who, 'sendNotifications' => true},
      body: details.to_json,
      headers: {'Content-Type' => 'application/json'}
    )
    @logger.debug ret.to_yaml
    ret
  end

  def events_as(who, date)
    auth_as

    date ||= Date.today

    @logger.info("Attempting to receive events for "+who)
    @logger.debug details.to_yaml

    ret = @client.execute(
      api_method: @calendar.events.list,
      parameters: {'calendarId' => who, 'sendNotifications' => true},
      body: details.to_json,
      headers: {'Content-Type' => 'application/json'}
    )

    @logger.debug ret.to_yaml
    ret    
  end
end
