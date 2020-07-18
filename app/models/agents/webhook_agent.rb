module Agents
  class WebhookAgent < Agent
    include EventHeadersConcern
    include WebRequestConcern  # to make reCAPTCHA verification requests

    cannot_be_scheduled!
    cannot_receive_events!

    description do <<-MD
      The Webhook Agent will create events by receiving webhooks from any source. In order to create events with this agent, make a POST request to:

      ```
         https://#{ENV['DOMAIN']}/users/#{user.id}/web_requests/#{id || ':id'}/#{options['secret'] || ':secret'}
      ```

      #{'The placeholder symbols above will be replaced by their values once the agent is saved.' unless id}

      Options:

        * `secret` - A token that the host will provide for authentication.
        * `expected_receive_period_in_days` - How often you expect to receive
          events this way. Used to determine if the agent is working.
        * `payload_path` - JSONPath of the attribute in the POST body to be
          used as the Event payload.  Set to `.` to return the entire message.
          If `payload_path` points to an array, Events will be created for each element.
        * `event_headers` - Comma-separated list of HTTP headers your agent will include in the payload.
        * `event_headers_key` - The key to use to store all the headers received
        * `verbs` - Comma-separated list of http verbs your agent will accept.
          For example, "post,get" will enable POST and GET requests. Defaults
          to "post".
        * `response` - The response message to the request. Defaults to 'Event Created'.
        * `response_headers` - An object with any custom response headers. (example: `{"Access-Control-Allow-Origin": "*"}`)
        * `code` - The response code to the request. Defaults to '201'. If the code is '301' or '302' the request will automatically be redirected to the url defined in "response".
        * `recaptcha_secret` - Setting this to a reCAPTCHA "secret" key makes your agent verify incoming requests with reCAPTCHA.  Don't forget to embed a reCAPTCHA snippet including your "site" key in the originating form(s).
        * `recaptcha_send_remote_addr` - Set this to true if your server is properly configured to set REMOTE_ADDR to the IP address of each visitor (instead of that of a proxy server).
      MD
    end

    event_description do
      <<-MD
        The event payload is based on the value of the `payload_path` option,
        which is set to `#{interpolated['payload_path']}`.
      MD
    end

    def default_options
      { "secret" => "supersecretstring",
        "expected_receive_period_in_days" => 1,
        "payload_path" => "some_key",
        "event_headers" => "",
        "event_headers_key" => "headers"
      }
    end

    def receive_web_request(request)
      # check the secret
      secret = request.path_parameters[:secret]
      return ["Not Authorized", 401] unless secret == interpolated['secret']

      params = request.query_parameters.dup
      begin
        params.update(request.request_parameters)
      rescue EOFError
      end

      method = request.method_symbol.to_s
      headers = request.headers.each_with_object({}) { |(name, value), hash|
        case name
        when /\AHTTP_([A-Z0-9_]+)\z/
          hash[$1.tr('_', '-').gsub(/[^-]+/, &:capitalize)] = value
        end
      }

      # check the verbs
      verbs = (interpolated['verbs'] || 'post').split(/,/).map { |x| x.strip.downcase }.select { |x| x.present? }
      return ["Please use #{verbs.join('/').upcase} requests only", 401] unless verbs.include?(method)

      # check the code
      code = (interpolated['code'].presence || 201).to_i

      # check the reCAPTCHA response if required
      if recaptcha_secret = interpolated['recaptcha_secret'].presence
        recaptcha_response = params.delete('g-recaptcha-response') or
          return ["Not Authorized", 401]

        parameters = {
          secret: recaptcha_secret,
          response: recaptcha_response,
        }

        if boolify(interpolated['recaptcha_send_remote_addr'])
          parameters[:remoteip] = request.env['REMOTE_ADDR']
        end

        begin
          response = faraday.post('https://www.google.com/recaptcha/api/siteverify',
                                  parameters)
        rescue => e
          error "Verification failed: #{e.message}"
          return ["Not Authorized", 401]
        end

        JSON.parse(response.body)['success'] or
          return ["Not Authorized", 401]
      end

      [payload_for(params)].flatten.each do |payload|
        create_event(payload: payload.merge(event_headers_payload(headers)))
      end

      if interpolated['response_headers'].presence
        [interpolated(params)['response'] || 'Event Created', code, "text/plain", interpolated['response_headers'].presence]
      else
        [interpolated(params)['response'] || 'Event Created', code]
      end
    end

    def working?
      event_created_within?(interpolated['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def validate_options
      unless options['secret'].present?
        errors.add(:base, "Must specify a secret for 'Authenticating' requests")
      end

      if options['code'].present? && options['code'].to_s !~ /\A\s*(\d+|\{.*)\s*\z/
        errors.add(:base, "Must specify a code for request responses")
      end

      if options['code'].to_s.in?(['301', '302']) && !options['response'].present?
        errors.add(:base, "Must specify a url for request redirect")
      end

      validate_event_headers_options!
    end

    def payload_for(params)
      Utils.value_at(params, interpolated['payload_path']) || {}
    end
  end
end
