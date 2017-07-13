module Agents
  class SurveyMonkeyAgent < Agent
    include WebRequestConcern
    include FormConfigurable

    UNIQUENESS_LOOK_BACK = 500
    UNIQUENESS_FACTOR = 5
    HTTP_METHOD = "get"
    SURVEYS_URL_BASE = "https://api.surveymonkey.net/v3/surveys"

    can_dry_run!
    no_bulk_receive!
    can_order_created_events!

    default_schedule "every_12h"

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
      {
        'api_token' => '{% credential SurveyMonkeyToken %}',
        'expected_update_period_in_days' => '2',
        'mode' => 'on_change'
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def http_method
      HTTP_METHOD
    end

    form_configurable :api_token
    form_configurable :survey_ids
    form_configurable :mode, type: :array, values: %w(all on_change merge)
    form_configurable :expected_update_period_in_days

    def validate_options
      errors.add(:base, "The 'api_token' option is required.") if options['api_token'].blank?

      if options['survey_ids'].blank?
        errors.add(:base, "The 'survey_ids' option is required.")
      end

      if options['expected_receive_period_in_days'].blank?
        errors.add(:base, "The 'expected_receive_period_in_days' option is required.")
      end

      if options['mode'].present?
        errors.add(:base, "mode must be set to on_change, all or merge") unless %w[on_change all merge].include?(options['mode'])
      end

      validate_web_request_options!
    end

    def check
      responses = surveys.map(&:parse_responses).flatten

      responses.each do |response|
        if store_payload!(previous_payloads(1), response)
          log "Storing new result for '#{name}': #{response.inspect}"
          create_event payload: response
        end
      end
    end

    private

    def headers(_ = {})
      { "Authorization" => "bearer #{interpolated['api_token']}" }
    end

    # TODO: move to a concern?
    def previous_payloads(num_events)
      # Larger of UNIQUENESS_FACTOR * num_events and UNIQUENESS_LOOK_BACK
      look_back = UNIQUENESS_FACTOR * num_events
      look_back = UNIQUENESS_LOOK_BACK if look_back < UNIQUENESS_LOOK_BACK

      events.order('id desc').limit(look_back) if interpolated['mode'] == 'on_change'
    end

    # TODO: move to a concern?
    # This method returns true if the result should be stored as a new event.
    # If mode is set to 'on_change', this method may return false and update an
    # existing event to expire further in the future.
    # Also, it will retrive asignee and/or ticket if the event should be stored.
    def store_payload!(old_events, result)
      case interpolated['mode'].presence
      when 'on_change'
        result_json = result.to_json
        if found = old_events.find { |event| event.payload.to_json == result_json }
          found.update!(expires_at: new_event_expiration_date)
          false
        else
          true
        end
      when 'all', 'merge', ''
        true
      else
        raise "Illegal options[mode]: #{interpolated['mode']}"
      end
    end

    def surveys
      @surveys ||= survey_ids.map do |survey_id|
        survey = fetch_survey_details(survey_id)
        survey['responses'] = fetch_survey_responses(survey_id)

        SurveyMonkeyParser.new(survey)
      end
    end

    def survey_ids
      @survey_ids ||= interpolated['survey_ids'].split(',').map(&:strip)
    end

    def fetch_survey_responses(survey_id)
      log "Fetching survey ##{survey_id} responses"
      url = "#{SURVEYS_URL_BASE}/#{survey_id}/responses/bulk"
      fetch_survey_monkey_resource(url)
    end

    def fetch_survey_details(survey_id)
      log "Fetching survey ##{survey_id} details"
      url = "#{SURVEYS_URL_BASE}/#{survey_id}/details"
      fetch_survey_monkey_resource(url)
    end

    def fetch_survey_monkey_resource(uri)
      response = faraday.get(uri)
      return {} unless response.success?

      JSON.parse(response.body)
    end
  end
end
