module Agents
  class ZendeskSatisfactionRatingsAgent < WebsiteAgent
    include FormConfigurable

    API_ENDPOINT = "/api/v2/satisfaction_ratings.json"
    DOMAIN = "zendesk.com"
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

    default_schedule "every_12h"

    before_validation :build_default_options

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
          * `retrieve_group` - If `true`, the agent wil use the `group_id`s received and find the associated `group`s
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

    form_configurable :subdomain
    form_configurable :account_email
    form_configurable :api_token
    form_configurable :filter
    form_configurable :mode, type: :array, values: %w(all on_change merge)
    form_configurable :retrieve_assignee, type: :array, values: %w(true false)
    form_configurable :retrieve_ticket, type: :array, values: %w(true false)
    form_configurable :retrieve_group, type: :array, values: %w(true false)
    form_configurable :expected_update_period_in_days

    def default_options
      {
        'subdomain' => 'myaccount',
        'filter' => 'sort_order=desc&score=received_with_comment',
        'account_email' => '{% credential ZendeskEmail %}',
        'api_token' => '{% credential ZendeskToken %}',
        'expected_update_period_in_days' => '2',
        'mode' => 'on_change',
        'retrieve_assignee' => 'true',
        'retrieve_ticket' => 'true'
      }
    end

    def validate_options
      super

      %w(subdomain account_email api_token).each do |key|
        errors.add(:base, "The '#{key}' option is required.") if options[key].blank?
      end

      if boolify(options['retrieve_assignee']).nil?
        errors.add(:base, "The retrieve_assignee option must be true or false")
      end

      if boolify(options['retrieve_ticket']).nil?
        errors.add(:base, "The retrieve_ticket option must be true or false")
      end
    end

    private

    def build_default_options
      options['url'] = "https://#{options['subdomain']}.#{DOMAIN}#{API_ENDPOINT}"
      options['url'] << "?#{options['filter']}" if options['filter'].present?
      options['basic_auth'] = "#{options['account_email']}/token:#{options['api_token']}"
      options['type'] = 'json'
      options['extract'] = EXTRACT
    end

    def retrieve_details!(data)
      data.merge!(get_assignee(data['assignee_id'])) if retrieve_assignee?
      data.merge!(get_ticket(data['ticket_id'])) if retrieve_ticket?
      data.merge!(get_group(data['group_id'])) if retrieve_group?
    end

    # This method returns true if the result should be stored as a new event.
    # If mode is set to 'on_change', this method may return false and update an
    # existing event to expire further in the future.
    # Also, it will retrive asignee and/or ticket if the event should be stored.
    def store_payload!(old_events, result)
      case interpolated['mode'].presence
      when 'on_change'
        found_event = old_events.find { |e| e.payload['id'] == result['id'] }
        if found_event
          found_event.update!(expires_at: new_event_expiration_date)
          false
        else
          retrieve_details!(result)
          true
        end
      when 'all', 'merge', ''
        retrieve_details!(result)
        true
      else
        raise "Illegal options[mode]: #{interpolated['mode']}"
      end
    end

    def retrieve_assignee?
      boolify(interpolated['retrieve_assignee'])
    end

    def retrieve_ticket?
      boolify(interpolated['retrieve_ticket'])
    end

    def retrieve_group?
      boolify(interpolated['retrieve_group'])
    end

    def get_assignee(assignee_id)
      log "Fetching assiginee #{assignee_id}"
      uri = "#{zendesk_uri_base}/users/#{assignee_id}.json"
      get_zendesk_resource(uri)
    end

    def get_ticket(ticket_id)
      log "Fetching ticket #{ticket_id}"
      uri = "#{zendesk_uri_base}/tickets/#{ticket_id}.json"
      get_zendesk_resource(uri)
    end

    def get_group(group_id)
      log "Fetching group #{group_id}"
      uri = "#{zendesk_uri_base}/groups/#{group_id}.json"
      get_zendesk_resource(uri)
    end

    def zendesk_uri_base
      "https://#{interpolated['subdomain']}.#{DOMAIN}/api/v2"
    end

    def get_zendesk_resource(uri)
      response = faraday.get(uri)
      return {} unless response.success?

      JSON.parse(response.body)
    end
  end
end
