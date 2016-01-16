module Agents
  class PostAgent < Agent
    include WebRequestConcern

    can_dry_run!
    default_schedule "never"

    description <<-MD
      A Post Agent receives events from other agents (or runs periodically), merges those events with the [Liquid-interpolated](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) contents of `payload`, and sends the results as POST (or GET) requests to a specified url.  To skip merging in the incoming event, but still send the interpolated payload, set `no_merge` to `true`.

      The `post_url` field must specify where you would like to send requests. Please include the URI scheme (`http` or `https`).

      The `method` used can be any of `get`, `post`, `put`, `patch`, and `delete`.

      By default, non-GETs will be sent with form encoding (`application/x-www-form-urlencoded`).  Change `content_type` to `json` to send JSON instead.  Change `content_type` to `xml` to send XML, where the name of the root element may be specified using `xml_root`, defaulting to `post`.

      If `emit_events` is set to `true`, the server response will be emitted as an Event and can be fed to a WebsiteAgent for parsing (using its `data_from_event` and `type` options). No data processing
      will be attempted by this Agent, so the Event's "body" value will always be raw text.

      Other Options:

        * `headers` - When present, it should be a hash of headers to send with the request.
        * `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
        * `disable_ssl_verification` - Set to `true` to disable ssl verification.
        * `user_agent` - A custom User-Agent name (default: "Faraday v#{Faraday::VERSION}").
    MD

    event_description <<-MD
      Events look like this:
        {
          "status": 200,
          "headers": {
            "Content-Type": "text/html",
            ...
          },
          "body": "<html>Some data...</html>"
        }
    MD

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
        'headers' => {},
        'emit_events' => 'false'
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

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
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
        when 'xml'
          headers['Content-Type'] = 'text/xml; charset=utf-8'
          body = data.to_xml(root: (interpolated(payload)[:xml_root] || 'post'))
        else
          body = data
        end
      else
        error "Invalid method '#{method}'"
      end

      response = faraday.run_request(method.to_sym, url, body, headers) { |request|
        request.params.update(params) if params
      }

      if boolify(interpolated['emit_events'])
        create_event payload: { body: response.body, headers: response.headers, status: response.status }
      end
    end
  end
end
