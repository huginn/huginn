module Agents
  class ZendeskSearchAgent < Agent
    include WebRequestConcern
    include FormConfigurable

    HTTP_METHOD = "get"
    API_ENDPOINTS = {
      "users" => "/api/v2/users",
      "tickets" => "/api/v2/tickets",
      "organizations" => "/api/v2/organizations"
    }
    DOMAIN = "zendesk.com"

    can_dry_run!
    no_bulk_receive!
    cannot_be_scheduled!

    before_validation :build_default_options

    description do
      <<-MD
        The Zendesk Search Agent receives events, find Zendesk resources and emit an event with the result.

        A Zendesk Search Agent can receives events from other agents, search resources by `id` (Users, Tickets and Organizations)
        and emit the result as an `event` with the data merged to the original payload if `merge` option is `true`.

        When `merge` is `true` search data is added to the event payload under the key `zendesk_search`.

        Options:

          * `subdomain` - Specify the subdomain of the Zendesk client (e.g `moo` or `hellofresh`).
          * `account_email` - Specify email to be used for Basic authentication.
          * `api_token` - Specify the token (or password) to be used for Basic authentication.
          * `resource` - Select the resource type to find (`users`, `tickets`, `organizations`).
          * `id` - Specify the Liquid interpolated expresion to get the `id` of the Zendesk user to find.
          * `merge` - Select `true` or `false`.
          * `expected_receive_period_in_days` - Specify the period in days used to calculate if the agent is working.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "status": 200,
          "data": "{...}"
        }
    MD

    def default_options
      {
        'subdomain' => 'myaccount',
        'account_email' => '{% credential ZendeskEmail %}',
        'api_token' => '{% credential ZendeskToken %}',
        'resource' => 'users',
        'id' => '{{ data.assignee_id }}',
        'merge' => 'true',
        'expected_receive_period_in_days' => '1'
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def http_method
      HTTP_METHOD
    end

    form_configurable :subdomain
    form_configurable :account_email
    form_configurable :api_token
    form_configurable :resource, type: :array, values: API_ENDPOINTS.keys
    form_configurable :id
    form_configurable :merge, type: :array, values: %w(true false)
    form_configurable :expected_receive_period_in_days

    def validate_options
      %w(subdomain account_email api_token id expected_receive_period_in_days).each do |key|
        if options[key].blank?
          errors.add(:base, "The '#{key}' option is required.")
        end
      end

      unless options['resource'].in?(API_ENDPOINTS.keys)
        valid_resources = API_ENDPOINTS.keys.to_sentence(last_word_connector: ' or ')
        errors.add(:base, "The 'resource' option must be #{valid_resources}.")
      end

      if boolify(options['merge']).nil?
        errors.add(:base, "The 'merge' option must be true or false")
      end

      validate_web_request_options!
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          handle(interpolated, event, headers)
        end
      end
    end

    def check
      handle(interpolated, headers)
    end

    private

    def build_default_options
      options['basic_auth'] = "#{options['account_email']}/token:#{options['api_token']}"
    end

    def request_url(event = Event.new)
      event_options = interpolated(event.payload)
      endpoint = API_ENDPOINTS[event_options['resource']]
      host = "#{event_options['subdomain']}.#{DOMAIN}"

      "https://#{host}#{endpoint}/#{event_options['id']}.json"
    end

    def handle(data, event = Event.new, headers)
      url = request_url(event)
      headers['Content-Type'] = 'application/json; charset=utf-8'
      response = faraday.run_request(http_method.to_sym, url, nil, headers)
      parsed_body = JSON.parse(response.body)

      data = if boolify(interpolated['merge'])
               event.payload.merge(zendesk_search: parsed_body)
             else
               parsed_body
             end

      create_event(payload: { data: data, status: response.status })
    end
  end
end
