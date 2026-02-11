module OpenaiConcern
  extend ActiveSupport::Concern

  included do
    include WebRequestConcern
  end

  OPENAI_BASE_URL = 'https://api.openai.com/v1'.freeze
  DEFAULT_OPENAI_TIMEOUT = 60 # seconds

  def openai_base_url
    url = interpolated['base_url'].presence ||
          ENV['OPENAI_BASE_URL'].presence ||
          OPENAI_BASE_URL
    url.chomp('/')
  end

  def openai_api_key
    interpolated['api_key'].presence ||
      ENV['OPENAI_API_KEY'].presence
  end

  def openai_timeout
    timeout = interpolated['request_timeout'].presence
    timeout ? timeout.to_i : DEFAULT_OPENAI_TIMEOUT
  end

  def openai_headers
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{openai_api_key}"
    }
    if interpolated['organization'].present?
      headers['OpenAI-Organization'] = interpolated['organization']
    end
    headers
  end

  # JSON-parsing request — used for most OpenAI API calls.
  def openai_request(method, path, body = nil)
    url = "#{openai_base_url}#{path}"
    conn = build_openai_connection(parse_json: true)
    response = conn.run_request(method, url, body&.to_json, openai_headers)
    response.body
  rescue Faraday::TimeoutError => e
    error("OpenAI API request timed out after #{openai_timeout}s: #{e.message}. Increase `request_timeout` for large inputs.")
    { 'error' => { 'message' => "Request timed out after #{openai_timeout}s" } }
  end

  # Multipart form request — used for file uploads (e.g. Whisper audio).
  def openai_multipart_request(path, form_data)
    url = "#{openai_base_url}#{path}"
    multipart_headers = openai_headers.except('Content-Type')
    conn = build_openai_connection(parse_json: false, multipart: true)

    response = conn.post(url) do |req|
      req.headers = multipart_headers
      req.body = form_data
    end

    JSON.parse(response.body)
  rescue Faraday::TimeoutError => e
    error("OpenAI API multipart request timed out after #{openai_timeout}s: #{e.message}. Increase `request_timeout` for large files.")
    { 'error' => { 'message' => "Request timed out after #{openai_timeout}s" } }
  rescue JSON::ParserError => e
    error("Failed to parse response: #{e.message}")
    { 'error' => { 'message' => "Invalid JSON response: #{response&.body&.truncate(500)}" } }
  end

  # Raw request (no JSON parsing) — used for binary responses like TTS audio
  # and for fetching external resources (e.g. audio files by URL).
  def openai_raw_request(method, path, body = nil)
    url = "#{openai_base_url}#{path}"
    conn = build_openai_connection(parse_json: false)
    conn.run_request(method, url, body&.to_json, openai_headers)
  rescue Faraday::TimeoutError => e
    error("OpenAI API request timed out after #{openai_timeout}s: #{e.message}. Increase `request_timeout`.")
    nil
  end

  # Raw Faraday connection for fetching external resources (e.g. audio URLs).
  # Does not add JSON parsing or OpenAI auth headers — callers set their own.
  def openai_raw_connection
    build_openai_connection(parse_json: false)
  end

  private

  # Builds a Faraday connection with shared SSL, timeout, proxy, user-agent,
  # and adapter configuration.  All OpenAI request helpers delegate here.
  #
  # Options:
  #   parse_json: true  — add `builder.response :json` middleware
  #   multipart:  true  — add multipart + url_encoded request middleware
  def build_openai_connection(parse_json: true, multipart: false)
    Faraday.new(
      ssl: { verify: !boolify(options['disable_ssl_verification']) },
      request: {
        timeout: openai_timeout,
        open_timeout: [openai_timeout, 60].min
      }
    ) do |builder|
      builder.response :json if parse_json

      builder.headers[:user_agent] = user_agent
      builder.proxy = interpolated['proxy'].presence

      unless boolify(interpolated['disable_redirect_follow'])
        require 'faraday/follow_redirects'
        builder.response :follow_redirects
      end

      if multipart
        builder.request :multipart
        builder.request :url_encoded
      end

      builder.request :gzip

      case backend = faraday_backend
      when :typhoeus
        require "faraday/#{backend}"
        builder.adapter backend, accept_encoding: nil
      when :httpclient, :em_http
        require "faraday/#{backend}"
        builder.adapter backend
      end
    end
  end

  public

  def validate_openai_options!
    unless options['api_key'].present? || ENV['OPENAI_API_KEY'].present?
      errors.add(:base, "api_key is required (set in agent options or via the OPENAI_API_KEY environment variable)")
    end

    if options['output_mode'].present? && !options['output_mode'].to_s.include?('{{') && !%w[clean merge].include?(options['output_mode'].to_s)
      errors.add(:base, "output_mode must be 'clean' or 'merge'")
    end

    if options['request_timeout'].present?
      timeout_val = options['request_timeout'].to_i
      if timeout_val <= 0
        errors.add(:base, "request_timeout must be a positive number of seconds")
      elsif timeout_val > 600
        errors.add(:base, "request_timeout cannot exceed 600 seconds")
      end
    end

    if options['expected_receive_period_in_days'].present?
      val = options['expected_receive_period_in_days'].to_i
      errors.add(:base, "expected_receive_period_in_days must be a positive number") if val <= 0
    end

    validate_web_request_options!
  end

  # Returns the base payload for a new event.  When output_mode is "merge"
  # and an incoming event is provided, the incoming payload is used as the
  # starting point so that the caller can `.merge()` its own fields on top.
  def openai_base_payload(event = nil)
    if event && interpolated['output_mode'].to_s == 'merge'
      event.payload.dup
    else
      {}
    end
  end

  def openai_working?
    !recent_error_logs?
  end

  def working?
    return false unless openai_working?

    if interpolated['expected_receive_period_in_days'].present?
      return false unless last_receive_at &&
        last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
    end

    true
  end

  def handle_openai_error(response)
    if response['error']
      error_msg = response['error']['message'] || response['error'].to_s
      error("OpenAI API error: #{error_msg}")
      true
    else
      false
    end
  end
end
