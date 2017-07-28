module Agents
  class GithubNotificationsAgent < Agent

    cannot_receive_events!
    can_dry_run!

    default_schedule "every_10m"

    description <<-MD
      The GithubNotificationsAgent fetches your notifications from Github.

      You need to create a [personal access token](https://github.com/settings/tokens) to use this, only the `notifications` scope is necessary.

      To emit all new notifications as a single event, change `events` to `single`. The event key will be `notifications`.

      To fetch all (unread) notifications, change `last_modified` to `false`. Default behaviour is to only fetch notifications that are updated since last run.

      More options might be added for the [API](https://developer.github.com/v3/activity/notifications/#list-your-notifications).

    MD

    def default_options
      {
        'access_token' => 'my_gh_access_token',
        'events' => 'multiple',
        'last_modified' => true
      }
    end

    def validate_options
      errors.add(:base, "access_token is required ") unless options['access_token'].present?
      errors.add(:base, "interval needs to be a positive integer") if options['interval'].present? &&  options['interval'].to_i <= 0
      if last_modified.present? && boolify(last_modified).nil?
        errors.add(:base, "last_modified must be a boolean value")
      end
    end

    def working?
      !recent_error_logs?
    end

    def check
      response = HTTParty.get base_url, request_options
      # If there are no new notifications, you will see a "304 Not Modified" response
      return if response.code == 304
      notifications = JSON.parse response.body
      if response.code > 400
        error("Error during http request: #{response.body}")
        return
      elsif emit_single_event?
        create_event payload: {notifications: notifications}
      else
        notifications.each {|notification| create_event payload: notification}
      end
      memory[:last_modified] = response.headers["last-modified"]
    end

    private

    def emit_single_event?
      options['events'] == 'single'
    end

    def last_modified
      options['last_modified']
    end

    def base_url
      "https://api.github.com/notifications"
    end

    def request_options
      {
        headers: default_headers.merge(extra_headers),
        query: query_parameters
      }
    end

    def default_headers
      {"User-Agent" => "Huginn (https://github.com/cantino/huginn)"}
    end

    def extra_headers
      (memory[:last_modified].present? && boolify(last_modified)) ? {'If-Modified-Since' => memory[:last_modified]} : {}
    end

    def query_parameters
      {
        access_token: interpolated['access_token']
      }
    end
  end
end
