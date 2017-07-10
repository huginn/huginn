module Agents
  class UsabillaAgent < Agent
    include FormConfigurable

    DEFAULT_DAYS_AGO = 1
    UNIQUENESS_LOOK_BACK = 500
    UNIQUENESS_FACTOR = 5

    gem_dependency_check { defined?(UsabillaApi) }

    EXTRACT = {
      'id' => { 'path' => 'satisfaction_ratings.[*].id' },
      'url' => { 'path' => 'satisfaction_ratings.[*].url' },
      'assignee_id' => { 'path' => 'satisfaction_ratings.[*].assignee_id' },
      'group_id' => { 'path' => 'satisfaction_ratings.[*].group_id' },
      'requester_id' => { 'path' => 'satisfaction_ratings.[*].requester_id' },
      'ticket_id' => { 'path' => 'satisfaction_ratings.[*].ticket_id' },
      'score' => { 'path' => 'satisfaction_ratings.[*].score' },
      'updated_at' => { 'path' => 'satisfaction_ratings.[*].updated_at' },
      'created_at' => { 'path' => 'satisfaction_ratings.[*].created_at' },
      'comment' => { 'path' => 'satisfaction_ratings.[*].comment' }
    }

    can_dry_run!
    can_order_created_events!
    no_bulk_receive!

    default_schedule 'every_1d'

    description do
      <<-MD
        The Zendesk Satisfaction Ratings Agent search Zendesk satisfaction ratings using their API and emit events with each result.

        A Zendesk Satisfaction Ratings can receives events from other agents, or run periodically,
        search ratings using the Zendesk API and emit the result as an `event` with the Zendesk `user` or `ticket` expanded
        if `retrieve_assiginee` or `retrieve_ticket` options are `true`.

        In the `on_change` mode, change is detected based on the resulted event payload after applying this option.
        If you want to add some keys to each event but ignore any change in them, set `mode` to `all` and put a DeDuplicationAgent downstream.
        If you specify `merge` for the `mode` option, Huginn will retain the old payload and update it with new values.

        Options:

          * `subdomain` - Specify the subdomain of the Zendesk client (e.g `moo` or `hellofresh`).
          * `account_email` - Specify email to be used for Basic authentication.
          * `api_token` - Specify the token (or password) to be used for Basic authentication.
          * `filter` - Extra params to be used to filter satisfaction ratings (e.g. score, start_time, end_time).
          * `mode` - Select the operation mode (`all`, `on_change`, `merge`).
          * `retrieve_assiginee` - If `true`, the agent wil use the `assiginee_id`s received and find the associated `assignee`s
          * `retrieve_ticket` - If `true`, the agent wil use the `ticket_id`s received and find the associated `ticket`s
          * `expected_receive_period_in_days` - Specify the period in days used to calculate if the agent is working.
      MD
    end

    event_description <<-MD
      Events look like this:
      {
        "id":              35436,
        "url":             "https://company.zendesk.com/api/v2/satisfaction_ratings/35436.json",
        "assignee_id":     135,
        "group_id":        44,
        "requester_id":    7881,
        "ticket_id":       208,
        "score":           "good",
        "updated_at":      "2011-07-20T22:55:29Z",
        "created_at":      "2011-07-20T22:55:29Z",
        "comment":         "Awesome support!",
        "user":            {...},
        "ticket":          {...}
      }
    MD

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    form_configurable :access_key
    form_configurable :secret_key
    form_configurable :mode, type: :array, values: %w(all on_change merge)
    form_configurable :retrieve_buttons, type: :array, values: %w(true false)
    form_configurable :buttons_to_retrieve
    form_configurable :retrieve_apps, type: :array, values: %w(true false)
    form_configurable :apps_to_retrieve
    form_configurable :retrieve_email, type: :array, values: %w(true false)
    form_configurable :emails_to_retrieve
    form_configurable :expected_update_period_in_days

    def default_options
      {
        'access_key' => '{% credential UsabillaAccessKey %}',
        'secret_key' => '{% credential UsabillaSecretKey %}',
        'expected_update_period_in_days' => '1',
        'mode' => 'on_change',
        'retrieve_buttons' => 'true',
        'retrieve_apps' => 'true',
        'retrieve_email' => 'true'
      }
    end

    def validate_options
      super

      %w(access_key secret_key).each do |key|
        errors.add(:base, "The '#{key}' option is required.") if options[key].blank?
      end

      if boolify(options['retrieve_buttons']).nil?
        errors.add(:base, "The retrieve_buttons option must be true or false")
      end

      if boolify(options['retrieve_apps']).nil?
        errors.add(:base, "The retrieve_apps option must be true or false")
      end

      if boolify(options['retrieve_email']).nil?
        errors.add(:base, "The retrieve_email option must be true or false")
      end
    end

    def check
      events = []
      events += retrieve_buttons if retrieve_buttons?
      events += retrieve_apps if retrieve_apps?
      events += retrieve_email if retrieve_email?

      payload = events.map { |e| usabilla_response_to_event(e) }

      payload.each do |e|
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

    def retrieve_buttons?
      boolify(interpolated['retrieve_buttons'])
    end

    def retrieve_apps?
      boolify(interpolated['retrieve_apps'])
    end

    def retrieve_email?
      boolify(interpolated['retrieve_email'])
    end

    def retrieve_buttons
      ids = interpolated['buttons_to_retrieve'] || '*'

      usabilla_api
        .websites_feedback
        .retrieve(
          id: ids,
          access_key: interpolated['access_key'],
          secret_key: interpolated['secret_key'],
          days_ago: DEFAULT_DAYS_AGO
        ).items
    end

    def retrieve_apps
      ids = interpolated['apps_to_retrieve'] || '*'

      usabilla_api
        .apps_feedback
        .retrieve(
          id: ids,
          access_key: interpolated['access_key'],
          secret_key: interpolated['secret_key'],
          days_ago: DEFAULT_DAYS_AGO
        ).items
    end

    def retrieve_email
      ids = interpolated['emails_to_retrieve'] || '*'

      usabilla_api
        .email_button
        .retrieve(
          id: ids,
          access_key: interpolated['access_key'],
          secret_key: interpolated['secret_key'],
          days_ago: DEFAULT_DAYS_AGO
        ).items
    end

    def usabilla_response_to_event(r)
      {
        comment: r.comment,
        score: r.rating,
        location: r.location,
        id: r.id,
        custom: r.custom,
        public_url: r.public_url,
        button_id: r.button_id,
        created_at: r.date,
        email: r.email
      }
    end

    def usabilla_api
      UsabillaApi
    end
  end
end
