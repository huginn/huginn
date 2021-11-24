module Agents
  class PostAgent < Agent
    include EventHeadersConcern
    include WebRequestConcern
    include FileHandling

    consumes_file_pointer!

    MIME_RE = /\A\w+\/.+\z/

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
        A Post Agent receives events from other agents (or runs periodically), merges those events with the [Liquid-interpolated](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) contents of `payload`, and sends the results as POST (or GET) requests to a specified url.  To skip merging in the incoming event, but still send the interpolated payload, set `no_merge` to `true`.

        The `post_url` field must specify where you would like to send requests. Please include the URI scheme (`http` or `https`).

        The `method` used can be any of `get`, `post`, `put`, `patch`, and `delete`.

        By default, non-GETs will be sent with form encoding (`application/x-www-form-urlencoded`).

        Change `content_type` to `json` to send JSON instead.

        Change `content_type` to `xml` to send XML, where the name of the root element may be specified using `xml_root`, defaulting to `post`.

        When `content_type` contains a [MIME](https://en.wikipedia.org/wiki/Media_type) type, and `payload` is a string, its interpolated value will be sent as a string in the HTTP request's body and the request's `Content-Type` HTTP header will be set to `content_type`. When `payload` is a string `no_merge` has to be set to `true`.

        If `emit_events` is set to `true`, the server response will be emitted as an Event and can be fed to a WebsiteAgent for parsing (using its `data_from_event` and `type` options). No data processing
        will be attempted by this Agent, so the Event's "body" value will always be raw text.
        The Event will also have a "headers" hash and a "status" integer value.

        If `output_mode` is set to `merge`, the emitted Event will be merged into the original contents of the received Event.

        Set `event_headers` to a list of header names, either in an array of string or in a comma-separated string, to include only some of the header values.

        Set `event_headers_style` to one of the following values to normalize the keys of "headers" for downstream agents' convenience:

          * `capitalized` (default) - Header names are capitalized; e.g. "Content-Type"
          * `downcased` - Header names are downcased; e.g. "content-type"
          * `snakecased` - Header names are snakecased; e.g. "content_type"
          * `raw` - Backward compatibility option to leave them unmodified from what the underlying HTTP library returns.

        Other Options:

          * `headers` - When present, it should be a hash of headers to send with the request.
          * `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
          * `disable_ssl_verification` - Set to `true` to disable ssl verification.
          * `user_agent` - A custom User-Agent name (default: "Faraday v#{Faraday::VERSION}").

        #{receiving_file_handling_agent_description}

        When receiving a `file_pointer` the request will be sent with multipart encoding (`multipart/form-data`) and `content_type` is ignored. `upload_key` can be used to specify the parameter in which the file will be sent, it defaults to `file`.
      MD
    end

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

      Original event contents will be merged when `output_mode` is set to `merge`.
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
        'emit_events' => 'false',
        'no_merge' => 'false',
        'output_mode' => 'clean'
      }
    end

    def working?
      return false if recent_error_logs?
      
      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def method
      (interpolated['method'].presence || 'post').to_s.downcase
    end

    def validate_options
      unless options['post_url'].present?
        errors.add(:base, "post_url is a required field")
      end

      if options['payload'].present? && %w[get delete].include?(method) && !(options['payload'].is_a?(Hash) || options['payload'].is_a?(Array))
        errors.add(:base, "if provided, payload must be a hash or an array")
      end

      if options['payload'].present? && %w[post put patch].include?(method)
        if !(options['payload'].is_a?(Hash) || options['payload'].is_a?(Array)) && options['content_type'] !~ MIME_RE
          errors.add(:base, "if provided, payload must be a hash or an array")
        end
      end

      if options['content_type'] =~ MIME_RE && options['payload'].is_a?(String) && boolify(options['no_merge']) != true
        errors.add(:base, "when the payload is a string, `no_merge` has to be set to `true`")
      end

      if options['content_type'] == 'form' && options['payload'].present? && options['payload'].is_a?(Array)
        errors.add(:base, "when content_type is a form, if provided, payload must be a hash")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      validate_event_headers_options!

      unless %w[post get put delete patch].include?(method)
        errors.add(:base, "method must be 'post', 'get', 'put', 'delete', or 'patch'")
      end

      if options['no_merge'].present? && !%[true false].include?(options['no_merge'].to_s)
        errors.add(:base, "if provided, no_merge must be 'true' or 'false'")
      end

      if options['output_mode'].present? && !options['output_mode'].to_s.include?('{') && !%[clean merge].include?(options['output_mode'].to_s)
        errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
      end

      unless headers.is_a?(Hash)
        errors.add(:base, "if provided, headers must be a hash")
      end

      validate_web_request_options!
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          outgoing = interpolated['payload'].presence || {}
          if boolify(interpolated['no_merge'])
            handle outgoing, event, headers(interpolated[:headers])
          else
            handle outgoing.merge(event.payload), event, headers(interpolated[:headers])
          end
        end
      end
    end

    def check
      handle interpolated['payload'].presence || {}, headers
    end

    private

    def handle(data, event = Event.new, headers)
      url = interpolated(event.payload)[:post_url]

      case method
      when 'get', 'delete'
        params, body = data, nil
      when 'post', 'put', 'patch'
        params = nil

        content_type =
          if has_file_pointer?(event)
            data[interpolated(event.payload)['upload_key'].presence || 'file'] = get_upload_io(event)
            nil
          else
            interpolated(event.payload)['content_type']
          end

        case content_type
        when 'json'
          headers['Content-Type'] = 'application/json; charset=utf-8'
          body = data.to_json
        when 'xml'
          headers['Content-Type'] = 'text/xml; charset=utf-8'
          body = data.to_xml(root: (interpolated(event.payload)[:xml_root] || 'post'))
        when MIME_RE
          headers['Content-Type'] = content_type
          body = data.to_s
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
        new_event = interpolated['output_mode'].to_s == 'merge' ? event.payload.dup : {}
        create_event payload: new_event.merge(
          body: response.body,
          status: response.status
        ).merge(
          event_headers_payload(response.headers)
        )
      end
    end

    def event_headers_key
      super || 'headers'
    end
  end
end
