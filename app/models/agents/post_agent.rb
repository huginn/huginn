module Agents
  class PostAgent < Agent
    cannot_create_events!

    default_schedule "never"

    description <<-MD
      A PostAgent receives events from other agents (or runs periodically), merges those events with the [Liquid-interpolated](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) contents of `payload`, and sends the results as POST (or GET) requests to a specified url.  To skip merging in the incoming event, but still send the interpolated payload, set `no_merge` to `true`.

      The `post_url` field must specify where you would like to send requests. Please include the URI scheme (`http` or `https`).

      The `method` used can be any of `get`, `post`, `put`, `patch`, and `delete`.

      By default, non-GETs will be sent with form encoding (`application/x-www-form-urlencoded`).  Change `content_type` to `json` to send JSON instead.

      The `headers` field is optional.  When present, it should be a hash of headers to send with the request.
    MD

    event_description "Does not produce events."

    def default_options
      {
        'post_url' => "http://www.example.com",
        'expected_receive_period_in_days' => '1',
        'content_type' => 'form',
        'method' => 'post',
        'payload' => {
          'key' => 'value',
          'something' => 'the event contained {{ somekey }}'
        },
        'headers' => {}
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def method
      (interpolated['method'].presence || 'post').to_s.downcase
    end

    def headers
      interpolated['headers'].presence || {}
    end

    def validate_options
      unless options['post_url'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, "post_url and expected_receive_period_in_days are required fields")
      end

      if options['payload'].present? && !options['payload'].is_a?(Hash)
        errors.add(:base, "if provided, payload must be a hash")
      end

      unless %w[post get put delete patch].include?(method)
        errors.add(:base, "method must be 'post', 'get', 'put', 'delete', or 'patch'")
      end

      if options['no_merge'].present? && !%[true false].include?(options['no_merge'].to_s)
        errors.add(:base, "if provided, no_merge must be 'true' or 'false'")
      end

      unless headers.is_a?(Hash)
        errors.add(:base, "if provided, headers must be a hash")
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        outgoing = interpolated(event.payload)['payload'].presence || {}
        if interpolated['no_merge'].to_s == 'true'
          handle outgoing
        else
          handle outgoing.merge(event.payload)
        end
      end
    end

    def check
      handle interpolated['payload'].presence || {}
    end

    def generate_uri(params = nil)
      uri = URI interpolated[:post_url]
      uri.query = URI.encode_www_form(Hash[URI.decode_www_form(uri.query || '')].merge(params)) if params
      uri
    end

    private

    def handle(data)
      if method == 'post'
        post_data(data, Net::HTTP::Post)
      elsif method == 'put'
        post_data(data, Net::HTTP::Put)
      elsif method == 'delete'
        post_data(data, Net::HTTP::Delete)
      elsif method == 'patch'
        post_data(data, Net::HTTP::Patch)
      elsif method == 'get'
        get_data(data)
      else
        error "Invalid method '#{method}'"
      end
    end

    def post_data(data, request_type = Net::HTTP::Post)
      uri = generate_uri
      req = request_type.new(uri.request_uri, headers)

      if interpolated['content_type'] == 'json'
        req.set_content_type('application/json', 'charset' => 'utf-8')
        req.body = data.to_json
      else
        req.form_data = data
      end

      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") { |http| http.request(req) }
    end

    def get_data(data)
      uri = generate_uri(data)
      req = Net::HTTP::Get.new(uri.request_uri, headers)
      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") { |http| http.request(req) }
    end
  end
end