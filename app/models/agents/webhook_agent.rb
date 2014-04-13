module Agents
  class WebhookAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!

    description  do
        <<-MD
        Use this Agent to create events by receiving webhooks from any source.

        In order to create events with this agent, make a POST request to:
        ```
           https://#{ENV['DOMAIN']}/users/#{user.id}/web_requests/#{id || '<id>'}/:secret
        ``` where `:secret` is specified in your options.

        The

        Options:

          * `secret` - A token that the host will provide for authentication.
          * `expected_receive_period_in_days` - How often you expect to receive
            events this way. Used to determine if the agent is working.
          * `payload_path` - JSONPath of the attribute in the POST body to be
            used as the Event payload.
      MD
    end

    event_description do
      <<-MD
        The event payload is base on the value of the `payload_path` option,
        which is set to `#{options['payload_path']}`.
      MD
    end

    def default_options
      { "secret" => "supersecretstring",
        "expected_receive_period_in_days" => 1,
        "payload_path" => "payload"}
    end

    def receive_web_request(params, method, format)
      secret = params.delete('secret')
      return ["Please use POST requests only", 401] unless method == "post"
      return ["Not Authorized", 401] unless secret == options['secret']

      create_event(:payload => payload_for(params))

      ['Event Created', 201]
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def validate_options
      unless options['secret'].present?
        errors.add(:base, "Must specify a secret for 'Authenticating' requests")
      end
    end

    def payload_for(params)
      Utils.value_at(params, options['payload_path']) || {}
    end
  end
end
