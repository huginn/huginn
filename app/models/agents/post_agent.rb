module Agents
  class PostAgent < Agent
    include WebRequestConcern

    cannot_create_events!

    default_schedule "never"

    description <<-MD
      A PostAgent receives events from other agents (or runs periodically), merges those events with the [Liquid-interpolated](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) contents of `payload`, and sends the results as POST (or GET) requests to a specified url.  To skip merging in the incoming event, but still send the interpolated payload, set `no_merge` to `true`.

      The `post_url` field must specify where you would like to send requests. Please include the URI scheme (`http` or `https`).

      The `method` used can be any of `get`, `post`, `put`, `patch`, and `delete`.

      By default, non-GETs will be sent with form encoding (`application/x-www-form-urlencoded`).  Change `content_type` to `json` to send JSON instead.

      Other Options:

        * `headers` - When present, it should be a hash of headers to send with the request.
        * `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
        * `disable_ssl_verification` - Set to `true` to disable ssl verification.
        * `user_agent` - A custom User-Agent name (default: "Faraday v#{Faraday::VERSION}").
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

      validate_web_request_options!
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        outgoing = interpolated(event)['payload'].presence || {}
        if boolify(interpolated['no_merge'])
          handle outgoing, event.payload
        else
          handle outgoing.merge(event.payload), event.payload
        end
      end
    end

    def check
      handle interpolated['payload'].presence || {}
    end

    private

    def handle(data, payload = {})
      url = interpolated(payload)[:post_url]
      headers = headers()

      case method
      when 'get', 'delete'
        params, body = data, nil
      when 'post', 'put', 'patch'
        params = nil

        case interpolated(payload)['content_type']
        when 'json'
          headers['Content-Type'] = 'application/json; charset=utf-8'
          body = data.to_json
        else
          body = data
        end
      else
        error "Invalid method '#{method}'"
      end

      faraday.run_request(method.to_sym, url, body, headers) { |request|
        request.params.update(params) if params
      }
    end
  end
end
