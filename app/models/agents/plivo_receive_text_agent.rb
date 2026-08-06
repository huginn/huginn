module Agents
  class PlivoReceiveTextAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!

    gem_dependency_check { defined?(Plivo) }

    description do
      <<~MD
        The Plivo Receive Text Agent receives text messages from Plivo and emits them as events.

        #{'## Include `plivo` in your Gemfile to use this Agent!' if dependencies_missing?}

        In order to create events with this agent, set the Message URL of your Plivo number (or application) to send POST requests to:

        ```
        #{post_url}
        ```

        #{'The placeholder symbols above will be replaced by their values once the agent is saved.' unless id}

        Options:

        * `server_url` must be set to the URL of your
        Huginn installation (probably "https://#{ENV['DOMAIN']}"), which must be web-accessible.  Be sure to set http/https correctly.

        * `auth_id` and `auth_token` are your Plivo account credentials. `auth_token` is used to validate the `X-Plivo-Signature-V3` header on incoming requests.

        * If `reply_text` is set, its contents will be sent back to the sender as a confirmation text.

        * `expected_receive_period_in_days` - How often you expect to receive events this way. Used to determine if the agent is working.
      MD
    end

    def default_options
      {
        'auth_id' => 'MAXXXXXXXXXXXXXXXXXX',
        'auth_token' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'server_url' => "https://#{ENV['DOMAIN'].presence || 'example.com'}",
        'reply_text' => '',
        'expected_receive_period_in_days' => 1
      }
    end

    def validate_options
      unless options['auth_id'].present? && options['auth_token'].present? && options['server_url'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, 'auth_id, auth_token, server_url, and expected_receive_period_in_days are all required')
      end
    end

    def working?
      event_created_within?(interpolated['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def post_url
      if interpolated['server_url'].present?
        "#{interpolated['server_url']}/users/#{user.id}/web_requests/#{id || ':id'}/sms-endpoint"
      else
        "https://#{ENV['DOMAIN']}/users/#{user.id}/web_requests/#{id || ':id'}/sms-endpoint"
      end
    end

    def receive_web_request(request)
      params = request.params.except(:action, :controller, :agent_id, :user_id, :format)
      method = request.method_symbol.to_s
      headers = request.headers

      # check the last url param: 'secret'
      secret = params.delete('secret')
      return ['Not Authorized', 401] unless secret == 'sms-endpoint'

      signature = headers['HTTP_X_PLIVO_SIGNATURE_V3']
      nonce = headers['HTTP_X_PLIVO_SIGNATURE_V3_NONCE']

      # validate the request came from Plivo (V3 signature over the URL + nonce)
      unless Plivo::Utils.valid_signatureV3?(post_url, nonce, signature, interpolated['auth_token'], method, params)
        error("Plivo Signature Failed to Validate\n\n" +
          "URL: #{post_url}\n\n" +
          "POST params: #{params.inspect}\n\n" +
          "Signature: #{signature}")
        return ['Not authorized', 401]
      end

      if create_event(payload: params)
        response = Plivo::XML::Response.new
        if interpolated['reply_text'].present?
          # Plivo's <Message> element needs an explicit sender and recipient:
          # reply from our number (the inbound `To`) back to the sender (`From`).
          response.addMessage(interpolated['reply_text'], src: params['To'], dst: params['From'])
        end
        [response.to_xml, 200, 'text/xml']
      else
        ['Bad request', 400]
      end
    end
  end
end
