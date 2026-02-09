module OpenaiConcern
  extend ActiveSupport::Concern

  included do
    include WebRequestConcern
    include FormConfigurable
  end

  OPENAI_BASE_URL = 'https://api.openai.com/v1'.freeze

  def openai_base_url
    url = interpolated['base_url'].presence || OPENAI_BASE_URL
    url.chomp('/')
  end

  def openai_api_key
    interpolated['api_key']
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

  def openai_request(method, path, body = nil)
    url = "#{openai_base_url}#{path}"
    response = faraday.run_request(method, url, body&.to_json, openai_headers)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    error("Failed to parse response: #{e.message}")
    { 'error' => { 'message' => "Invalid JSON response: #{response&.body&.truncate(500)}" } }
  end

  def openai_multipart_request(path, form_data)
    url = "#{openai_base_url}#{path}"
    multipart_headers = openai_headers.except('Content-Type')

    conn = Faraday.new(url: url) do |f|
      f.request :multipart
      f.request :url_encoded
      f.adapter faraday_backend
    end

    response = conn.post do |req|
      req.headers = multipart_headers
      form_data.each do |key, value|
        req.body ||= {}
        req.body[key] = value
      end
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    error("Failed to parse response: #{e.message}")
    { 'error' => { 'message' => "Invalid JSON response: #{response&.body&.truncate(500)}" } }
  end

  def validate_openai_options!
    errors.add(:base, "api_key is required") unless options['api_key'].present?
    validate_web_request_options!
  end

  def openai_working?
    !recent_error_logs?
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

  def parse_body?
    true
  end
end
