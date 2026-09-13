require "timeout"

# Applies finite, job-aware timeouts to outbound network clients.
module NetworkTimeout
  DEFAULT_OPEN_TIMEOUT = 10
  DEFAULT_TIMEOUT = 60
  MAX_RUNTIME_MARGIN = 2

  module_function

  def timeout(requested = nil)
    values = [configured_timeout, maximum_timeout]
    values << positive_timeout(requested, "requested timeout") unless requested.nil?
    values.min
  end

  def open_timeout(requested = nil)
    value = requested || ENV.fetch("OUTBOUND_NETWORK_OPEN_TIMEOUT", DEFAULT_OPEN_TIMEOUT)
    [positive_timeout(value, "OUTBOUND_NETWORK_OPEN_TIMEOUT"), timeout].min
  end

  def configure!
    request_options = Faraday.default_connection_options.request
    request_options.open_timeout = open_timeout
    request_options.timeout = timeout
    request_options.read_timeout = timeout
    request_options.write_timeout = timeout

    Typhoeus::Config.connecttimeout = open_timeout
    Typhoeus::Config.timeout = timeout

    httparty_clients = [HTTParty::Basement]
    httparty_clients << HTTMultiParty::Basement if defined?(HTTMultiParty)
    if defined?(HipChat)
      httparty_clients.concat([HipChat::Client, HipChat::Room, HipChat::User])
    end
    httparty_clients.each do |client|
      configure_httparty(client)
    end

    Aws.config.update(
      http_open_timeout: open_timeout,
      http_read_timeout: timeout
    ) if defined?(Aws)

    if defined?(Google::Apis::ClientOptions)
      google_options = Google::Apis::ClientOptions.default
      google_options.open_timeout_sec = open_timeout
      google_options.read_timeout_sec = timeout
      google_options.send_timeout_sec = timeout
    end

    if defined?(Twilio::HTTP::Client)
      Twilio.configure { |config| config.http_client = Twilio::HTTP::Client.new(timeout:) }
    end

    smtp_settings = ActionMailer::Base.smtp_settings
    smtp_settings[:open_timeout] = open_timeout(ENV["SMTP_OPEN_TIMEOUT"])
    smtp_settings[:read_timeout] = timeout(ENV["SMTP_READ_TIMEOUT"])
  end

  def configure_httparty(client)
    client.default_timeout(timeout)
    client.open_timeout(open_timeout)
    client.read_timeout(timeout)
    client.write_timeout(timeout)
  end

  def configure_net_http(http)
    http.open_timeout = open_timeout
    http.read_timeout = timeout
    http.write_timeout = timeout if http.respond_to?(:write_timeout=)
    http
  end

  def http_options
    {
      open_timeout:,
      read_timeout: timeout,
      write_timeout: timeout,
    }
  end

  def open_uri_options
    { open_timeout:, read_timeout: timeout }
  end

  def within(requested = nil, &block)
    Timeout.timeout(timeout(requested), Timeout::Error, &block)
  end

  def configured_timeout
    value = ENV.fetch("OUTBOUND_NETWORK_TIMEOUT", DEFAULT_TIMEOUT)
    positive_timeout(value, "OUTBOUND_NETWORK_TIMEOUT")
  end

  def maximum_timeout
    maximum = Delayed::Worker.max_run_time.to_f - MAX_RUNTIME_MARGIN
    raise ArgumentError, "DELAYED_JOB_MAX_RUNTIME must exceed #{MAX_RUNTIME_MARGIN} seconds" unless maximum.positive?

    maximum
  end

  def positive_timeout(value, name)
    value = Float(value)
    raise ArgumentError unless value.positive? && value.finite?

    value
  rescue ArgumentError, TypeError
    raise ArgumentError, "#{name} must be a positive number of seconds"
  end
end
