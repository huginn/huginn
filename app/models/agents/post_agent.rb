module Agents
  class PostAgent < Agent
    cannot_create_events!

    default_schedule "never"

    description <<-MD
      A PostAgent receives events from other agents (or runs periodically), merges those events with the contents of `payload`, and sends the results as POST (or GET) requests to a specified url.

      The `post_url` field must specify where you would like to send requests. Please include the URI scheme (`http` or `https`).

      The `headers` field is optional.  When present, it should be a hash of headers to send with the request.
    MD

    event_description "Does not produce events."

    def default_options
      {
        'post_url' => "http://www.example.com",
        'expected_receive_period_in_days' => 1,
        'method' => 'post',
        'payload' => {
          'key' => 'value'
        },
        'headers' => {}
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def method
      (options['method'].presence || 'post').to_s.downcase
    end

    def headers
      options['headers'].presence || {}
    end

    def validate_options
      unless options['post_url'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, "post_url and expected_receive_period_in_days are required fields")
      end

      if options['payload'].present? && !options['payload'].is_a?(Hash)
        errors.add(:base, "if provided, payload must be a hash")
      end

      unless %w[post get].include?(method)
        errors.add(:base, "method must be 'post' or 'get'")
      end

      unless headers.is_a?(Hash)
        errors.add(:base, "if provided, headers must be a hash")
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        handle (options['payload'].presence || {}).merge(event.payload)
      end
    end

    def check
      handle options['payload'].presence || {}
    end

    def generate_uri(params = nil)
      uri = URI options[:post_url]
      uri.query = URI.encode_www_form(Hash[URI.decode_www_form(uri.query || '')].merge(params)) if params
      uri
    end

    private

    def handle(data)
      if method == 'post'
        post_data(data)
      elsif method == 'get'
        get_data(data)
      else
        error "Invalid method '#{method}'"
      end
    end

    def post_data(data)
      uri = generate_uri
      req = Net::HTTP::Post.new(uri.request_uri, headers)
      req.form_data = data
      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") { |http| http.request(req) }
    end

    def get_data(data)
      uri = generate_uri(data)
      req = Net::HTTP::Get.new(uri.request_uri, headers)
      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") { |http| http.request(req) }
    end
  end
end