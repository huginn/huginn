module Agents
  class SlackAgent < Agent
    DEFAULT_USERNAME = 'Huginn'

    cannot_be_scheduled!
    cannot_create_events!

    gem_dependency_check { defined?(Slack) }

    description <<-MD
      #{'## Include `slack-notifier` in your Gemfile to use this Agent!' if dependencies_missing?}
      The SlackAgent lets you receive events and send notifications to [Slack](https://slack.com/).

      To get started, you will first need to setup an incoming webhook.
      Go to, <code>https://<em>your_team_name</em>.slack.com/services/new/incoming-webhook</code>,
      choose a default channel and add the integration.

      Your webhook URL will look like: <code>https://hooks.slack.com/services/<em>random1</em>/<em>random2</em>/<em>token</em></code>

      Once the webhook has been setup it can be used to post to other channels or ping team members.
      To send a private message to team-mate, assign his username as `@username` to the channel option.
      To communicate with a different webhook on slack, assign your custom webhook name to the webhook option.
      Messages can also be formatted using [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid)
    MD

    def default_options
      {
        'webhook_url' => 'https://hooks.slack.com/services/...',
        'channel' => '#general',
        'username' => DEFAULT_USERNAME,
        'message' => "Hey there, It's Huginn",
      }
    end

    def validate_options
      unless options['webhook_url'].present? ||
             (options['auth_token'].present? && options['team_name'].present?)  # compatibility
        errors.add(:base, "webhook_url is required")
      end

      errors.add(:base, "channel is required") unless options['channel'].present?
    end

    def working?
      received_event_without_error?
    end

    def webhook_url
      case
      when url = interpolated[:webhook_url].presence
        url
      when (team = interpolated[:team_name].presence) && (token = interpolated[:auth_token])
        webhook = interpolated[:webhook].presence || 'incoming-webhook'
        # old style webhook URL
        "https://#{Rack::Utils.escape_path(team)}.slack.com/services/hooks/#{Rack::Utils.escape_path(webhook)}?token=#{Rack::Utils.escape(token)}"
      end
    end

    def username
      interpolated[:username].presence || DEFAULT_USERNAME
    end

    def slack_notifier
      @slack_notifier ||= Slack::Notifier.new(webhook_url, username: username)
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        opts = interpolated(event)
        slack_notifier.ping opts[:message], channel: opts[:channel], username: opts[:username]
      end
    end
  end
end
