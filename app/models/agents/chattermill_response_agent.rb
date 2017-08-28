module Agents
  class ChattermillResponseAgent < Agent
    include WebRequestConcern
    include FormConfigurable

    API_ENDPOINT = "/webhooks/responses"
    BASIC_OPTIONS = %w(comment score kind stream created_at user_meta segments)
    DOMAINS = {
      production: "app.chattermill.xyz",
      development: "lvh.me:3000",
      test: "localhost:3000"
    }

    can_dry_run!
    no_bulk_receive!
    cannot_be_scheduled!

    before_validation :parse_json_options

    description do
      <<-MD
        The Chattermill Response Agent receives events, build responses, and sends the results using the Chattermill API.

        A Chattermill Response Agent can receives events from other agents or run periodically,
        it builds Chattermill Responses with the [Liquid-interpolated](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid)
        contents of `options`, and sends the results as Authenticated POST requests to a specified API instance.
        If the request fail, a notification to Slack will be sent.

        If `emit_events` is set to `true`, the server response will be emitted as an Event and can be fed to a
        WebsiteAgent for parsing (using its `data_from_event` and `type` options). No data processing
        will be attempted by this Agent, so the Event's "body" value will always be raw text.
        The Event will also have a "headers" hash and a "status" integer value.
        Header names are capitalized; e.g. "Content-Type".

        Options:

          * `organization_subdomain` - Specify the subdomain for the target organization (e.g `moo` or `hellofresh`).
          * `comment` - Specify the Liquid interpolated expresion to build the Response comment.
          * `score` - Specify the Liquid interpolated expresion to build the Response score.
          * `kind` - Specify the Liquid interpolated expresion to build the Response kind.
          * `stream` - Specify the Liquid interpolated expresion to build the Response stream.
          * `created_at` - Specify the Liquid interpolated expresion to build the Response created_at date.
          * `user_meta` - Specify the Liquid interpolated JSON to build the Response user metas.
          * `segments` - Specify the Liquid interpolated JSON to build the Response segments.
          * `extra_fields` - Specify the Liquid interpolated JSON to build additional fields for the Response, e.g: `{ approved: true }`.
          * `emit_events` - Select `true` or `false`.
          * `expected_receive_period_in_days` - Specify the period in days used to calculate if the agent is working.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "status": 201,
          "headers": {
            "Content-Type": "'application/json",
            ...
          },
          "body": "{...}"
        }
    MD

    def default_options
      sample_hash = Utils.pretty_jsonify(
        sample_id: { type: "text", name: "Sample Id", value: "{{data.sample_id}}" }
      )

      {
        'comment' => '{{ data.comment }}',
        'score' => '{{ data.score }}',
        'kind' => 'nps',
        'stream' => 'nps_survey',
        'created_at' => '{{ data.date }}',
        'user_meta' => sample_hash,
        'segments' => sample_hash,
        'extra_fields' => '{}',
        'emit_events' => 'true',
        'expected_receive_period_in_days' => '1'
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def http_method
      has_id? ? :patch : :post
    end

    form_configurable :organization_subdomain
    form_configurable :id
    form_configurable :comment
    form_configurable :score
    form_configurable :kind
    form_configurable :stream
    form_configurable :created_at
    form_configurable :user_meta, type: :json, ace: { mode: 'json' }
    form_configurable :segments, type: :json, ace: { mode: 'json' }
    form_configurable :extra_fields, type: :json, ace: { mode: 'json' }
    form_configurable :emit_events, type: :boolean
    form_configurable :expected_receive_period_in_days

    def validate_options
      if options['organization_subdomain'].blank?
        errors.add(:base, "The 'organization_subdomain' option is required.")
      end
      if options['expected_receive_period_in_days'].blank?
        errors.add(:base, "The 'expected_receive_period_in_days' option is required.")
      end

      if options.key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      validate_web_request_options!
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          outgoing = interpolated.slice(*BASIC_OPTIONS).select { |_, v| v.present? }
          outgoing.merge!(interpolated['extra_fields'].presence || {})

          handle outgoing, event, headers(auth_header)
        end
      end
    end

    def check
      outgoing = interpolated.slice(*BASIC_OPTIONS).select { |_, v| v.present? }
      outgoing.merge!(interpolated['extra_fields'].presence || {})

      handle outgoing, headers(auth_header)
    end

    private

    def parse_json_options
      parse_json_option('user_meta')
      parse_json_option('segments')
      parse_json_option('extra_fields')
    end

    def parse_json_option(key)
      options[key] = JSON.parse(options[key]) unless options[key].is_a?(Hash)
    rescue
      errors.add(:base, "The '#{key}' option is an invalid JSON.")
    end

    def normalize_response_headers(headers)
      case interpolated['event_headers_style']
      when nil, '', 'capitalized'
        normalize = ->name {
          name.gsub(/(?:\A|(?<=-))([[:alpha:]])|([[:alpha:]]+)/) {
            $1 ? $1.upcase : $2.downcase
          }
        }
      when 'downcased'
        normalize = :downcase.to_proc
      when 'snakecased', nil
        normalize = ->name { name.tr('A-Z-', 'a-z_') }
      when 'raw'
        normalize = ->name { name }  # :itself.to_proc in Ruby >= 2.2
      else
        raise ArgumentError, "if provided, event_headers_style must be 'capitalized', 'downcased', 'snakecased' or 'raw'"
      end

      headers.each_with_object({}) { |(key, value), hash|
        hash[normalize[key]] = value
      }
    end

    def request_url(event = Event.new)
      protocol = Rails.env.production? ? 'https' : 'http'
      domain = DOMAINS[Rails.env.to_sym]
      "#{protocol}://#{domain}#{API_ENDPOINT}/#{interpolated['id']}"
    end

    def has_id?
      interpolated['id'].present?
    end

    def auth_header
      {
        "Authorization" => "Bearer #{ENV['CHATTERMILL_AUTH_TOKEN']}",
        "Organization" => interpolated['organization_subdomain']
      }
    end

    def handle(data, event = Event.new, headers)
      url = request_url(event)
      headers['Content-Type'] = 'application/json; charset=utf-8'
      body = data.to_json
      response = faraday.run_request(http_method, url, body, headers)
      send_slack_notification(response, event) unless [200, 201].include?(response.status)

      return unless boolify(interpolated['emit_events'])
      create_event(payload: { body: response.body,
                              headers: normalize_response_headers(response.headers),
                              status: response.status })
    end

    def send_slack_notification(response, event)
      link = "<https://huginn.chattermill.xyz/agents/#{event.agent_id}/events|Details>"
      parsed_body = JSON.parse(response.body) rescue ""
      description = "```#{parsed_body}```\n#{link}"
      slack_opts = {
        icon_emoji: ':fire:',
        channel: ENV['SLACK_CHANNEL'],
        attachments: [
          {
            title: "Error #{response.status} on #{name}",
            author_name: event.agent&.name,
            color: "danger",
            text: description,
            fallback: description,
            mrkdwn_in: [
                "text"
            ]
          }
        ]
      }

      slack_notifier.ping('', slack_opts)
    end

    def slack_notifier
      @slack_notifier ||= Slack::Notifier.new(ENV['SLACK_WEBHOOK_URL'], username: 'Huginn')
    end
  end
end
