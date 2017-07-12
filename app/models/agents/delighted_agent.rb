module Agents
  class DelightedAgent < Agent
    include FormConfigurable

    UNIQUENESS_LOOK_BACK = 500
    UNIQUENESS_FACTOR = 5

    gem_dependency_check { defined?(Delighted) }

    can_dry_run!
    can_order_created_events!
    no_bulk_receive!

    default_schedule 'every_5h'

    description <<-MD
      Delighted Agent fetches responses from the Delighted API given client's access details.

      In the `on_change` mode, change is detected based on the resulted event payload after applying this option.
      If you want to add some keys to each event but ignore any change in them, set `mode` to `all` and put a DeDuplicationAgent downstream.
      If you specify `merge` for the `mode` option, Huginn will retain the old payload and update it with new values.

      Options:

        * `api_key` - Delighted API Key.
        * `mode` - Select the operation mode (`all`, `on_change`, `merge`).
        * `expected_receive_period_in_days` - Specify the period in days used to calculate if the agent is working.
    MD

    event_description <<-MD
      Events look like this:
        {
          "score": 9,
          "comment": "Love the concept and the food! Just a little too expensive.",
          "permalink": "https://delighted.com/r/hqt5a8UlaZ1Vie9vsdSCtpo3iJaLrZPX",
          "created_at": 1499888649,
          "updated_at": 1499888686,
          "person_properties": {},
          "notes": [
          ],
          "tags": [
          ],
          "person": "138373225"
      }
    MD

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    form_configurable :api_key
    form_configurable :mode, type: :array, values: %w(all on_change merge)
    form_configurable :expected_update_period_in_days

    def default_options
      {
        'api_key' => '{% credential DelightedApiKey %}',
        'expected_update_period_in_days' => '1',
        'mode' => 'on_change'
      }
    end

    def validate_options
      super

      %w(api_key).each do |key|
        errors.add(:base, "The '#{key}' option is required.") if options[key].blank?
      end
    end

    def check
      delighted_events.each do |e|
        if store_payload!(previous_payloads(1), e)
          log "Storing new result for '#{name}': #{e.inspect}"
          create_event payload: e
        end
      end
    end

    private

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

    def delighted_events
      list_delighted_responses.map(&:to_h)
    end

    def list_delighted_responses
      Delighted::SurveyResponse.all(default_query, delighted_client)
    end

    def default_query
      {
        order: 'desc',
        per_page: 100,
        expand: ['person']
      }
    end

    def delighted_client
      @delighted_client ||= Delighted::Client.new(api_key: interpolated['api_key'])
    end
  end
end
