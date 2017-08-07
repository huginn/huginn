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
        The Survey Monkey Agent pull surveys responses via [SurveyMonkey API](https://developer.surveymonkey.com/api/v3/#surveys-id-responses-bulk),
        extract a `comment` and calculates a `score` based on available questions, then it sends the results as events.

        With `on_change` mode selected, changes are detected based on the resulted event payload after applying this option.
        If you want to add some keys to each event but ignore any change in them, set `mode` to `all` and put a DeDuplicationAgent downstream.
        If you specify `merge` for the `mode` option, Huginn will retain the old payload and update it with new values.

        Options:

          * `api_token` - Specify the SurveyMonkey API token for authentication.
          * `survey_ids` - Specify the list of survey IDs for which Huginn will retrieve responses.
          * `mode` - Select the operation mode (`all`, `on_change`, `merge`).
          * `expected_update_period_in_days` - Specify the period in days used to calculate if the agent is working.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "score": 2,
          "comment": "Sometimes the website is hanged, not so stable.",
          "response_id": "783280986",
          "survey_id": "10172078",
          "created_at": "2009-04-30T01:45:11+00:00",
          "language": "en"
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
      last_receive_at && last_receive_at > interpolated['expected_update_period_in_days'].to_i.days.ago && !recent_error_logs?
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

      if options['expected_update_period_in_days'].blank?
        errors.add(:base, "The 'expected_update_period_in_days' option is required.")
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

    def previous_payloads(num_events)
      # Larger of UNIQUENESS_FACTOR * num_events and UNIQUENESS_LOOK_BACK
      look_back = UNIQUENESS_FACTOR * num_events
      look_back = UNIQUENESS_LOOK_BACK if look_back < UNIQUENESS_LOOK_BACK

      events.order('id desc').limit(look_back) if interpolated['mode'] == 'on_change'
    end

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
      url = "#{SURVEYS_URL_BASE}/#{survey_id}/responses/bulk?sort_by=date_modified&sort_order=DESC&status=completed"
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
