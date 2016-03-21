module Agents
  class SlackAgent < Agent
    DEFAULT_USERNAME = 'Huginn'
    ALLOWED_PARAMS = ['channel', 'username', 'unfurl_links', 'attachments']

    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    gem_dependency_check { defined?(Slack) }

    description <<-MD
      The Slack Agent lets you receive events and send notifications to [Slack](https://slack.com/).

      #{'## Include `slack-notifier` in your Gemfile to use this Agent!' if dependencies_missing?}

      To get started, you will first need to configure an incoming webhook.

      - Go to `https://my.slack.com/services/new/incoming-webhook`, choose a default channel and add the integration.

      Your webhook URL will look like: `https://hooks.slack.com/services/some/random/characters`

      Once the webhook has been configured, it can be used to post to other channels or direct to team members. To send a private message to team member, use their @username as the channel. Messages can be formatted using [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid).

      Finally, you can set a custom icon for this webhook in `icon`, either as [emoji](http://www.emoji-cheat-sheet.com) or an URL to an image. Leaving this field blank will use the default icon for a webhook.
    MD

    def default_options
      {
        'webhook_url' => 'https://hooks.slack.com/services/...',
        'channel' => '#general',
        'username' => DEFAULT_USERNAME,
        'message' => "Hey there, It's Huginn",
        'icon' => '',
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

    def filter_options(opts)
      opts.select { |key, value| ALLOWED_PARAMS.include? key }.symbolize_keys
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        opts = interpolated(event)
        slack_opts = filter_options(opts)
        if opts[:icon].present?
          if /^:/.match(opts[:icon])
            slack_opts[:icon_emoji] = opts[:icon]
          else
            slack_opts[:icon_url] = opts[:icon]
          end
        end
        slack_notifier.ping opts[:message], slack_opts
      end
    end
  end
end
