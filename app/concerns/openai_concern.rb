module OpenaiConcern
  extend ActiveSupport::Concern

  included do
    include WebRequestConcern
  end

  OPENAI_BASE_URI = URI('https://api.openai.com/v1/').freeze
  DEFAULT_OPENAI_TIMEOUT = 60 # seconds

  def openai_base_uri
    url = interpolated['base_url'].presence ||
          ENV['OPENAI_BASE_URL'].presence
    return OPENAI_BASE_URI unless url

    URI(url.sub(%r{/?\z}, "/"))
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
      'Authorization' => "Bearer #{openai_api_key}"
    }
    if interpolated['organization'].present?
      headers['OpenAI-Organization'] = interpolated['organization']
    end
    headers
  end

  # JSON-parsing request — used for most OpenAI API calls.
  # Returns the parsed response body on success, or nil on failure
  # (after logging the error via handle_openai_error).
  def openai_request(method, path, body = nil)
    url = openai_base_uri + path
    conn = build_openai_connection
    response = conn.run_request(method, url, body, openai_headers)
    return nil if handle_openai_error(response)

    response.body
  rescue Faraday::TimeoutError => e
    error("OpenAI API request timed out after #{openai_timeout}s: #{e.message}. Increase `request_timeout` for large inputs.")
    nil
  end

  # Multipart form request — used for file uploads (e.g. Whisper audio).
  # The :json response middleware is always active; Faraday only parses
  # when the response Content-Type contains "json", so plain-text formats
  # (text, srt, vtt) are returned as raw strings automatically.
  # Returns the parsed response body on success, or nil on failure.
  def openai_multipart_request(path, form_data)
    url = openai_base_uri + path
    conn = build_openai_connection(multipart: true)

    response = conn.post(url) do |req|
      req.headers.update(openai_headers)
      req.body = form_data
    end

    return nil if handle_openai_error(response)

    response.body
  rescue Faraday::TimeoutError => e
    error("OpenAI API multipart request timed out after #{openai_timeout}s: #{e.message}. Increase `request_timeout` for large files.")
    nil
  end

  # Raw request — used for binary responses like TTS audio where we need
  # access to the raw Faraday response object (status, headers, body).
  # The :json middleware is still active but won't fire for non-JSON content types.
  # Returns the Faraday response on success, or nil on failure.
  def openai_raw_request(method, path, body = nil)
    url = openai_base_uri + path
    conn = build_openai_connection
    response = conn.run_request(method, url, body, openai_headers)
    return nil if handle_openai_error(response)

    response
  rescue Faraday::TimeoutError => e
    error("OpenAI API request timed out after #{openai_timeout}s: #{e.message}. Increase `request_timeout`.")
    nil
  end

  # Raw Faraday connection for fetching external resources (e.g. audio URLs).
  # Does not add OpenAI auth headers — callers set their own.
  def openai_raw_connection
    build_openai_connection
  end

  private

  # Builds a Faraday connection with shared SSL, timeout, proxy, user-agent,
  # and adapter configuration.  All OpenAI request helpers delegate here.
  #
  # The :json request middleware auto-serializes Hash/Array bodies and sets
  # Content-Type to application/json.  The :json response middleware decodes
  # JSON response bodies; non-JSON responses are passed through unchanged.
  #
  # Options:
  #   multipart: true  — use multipart + url_encoded instead of :json request
  def build_openai_connection(multipart: false)
    Faraday.new(
      ssl: { verify: !boolify(options['disable_ssl_verification']) },
      request: {
        timeout: openai_timeout,
        open_timeout: [openai_timeout, 60].min
      }
    ) do |builder|
      builder.response :json

      builder.headers[:user_agent] = user_agent
      builder.proxy = interpolated['proxy'].presence

      unless boolify(interpolated['disable_redirect_follow'])
        require 'faraday/follow_redirects'
        builder.response :follow_redirects
      end

      if multipart
        builder.request :multipart
        builder.request :url_encoded
      else
        builder.request :json
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

  # Inspects a Faraday response for errors.  Returns true (and logs the
  # error) when the request failed, false otherwise.  Handles non-Hash
  # bodies defensively — Faraday's :json middleware always decodes JSON
  # responses, so the body may be a Hash, Array, String, or nil.
  def handle_openai_error(response)
    return false if response.success?

    body = response.body

    if body.is_a?(Hash) && body['error']
      err = body['error']
      error_msg = err.is_a?(Hash) ? (err['message'] || err.to_s) : err.to_s
      error("OpenAI API error (HTTP #{response.status}): #{error_msg}")
    else
      error("OpenAI API error (HTTP #{response.status}): #{body.to_s.truncate(500)}")
    end

    true
  end
end
