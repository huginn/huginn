module Agents
  class SlackAgent < Agent
    include LiquidInterpolatable
    cannot_be_scheduled!
    cannot_create_events!

    DEFAULT_WEBHOOK = 'incoming-webhook'
    DEFAULT_USERNAME = 'Huginn'
    description <<-MD
      The SlackAgent lets you receive events and send notifications to [slack](https://slack.com/).

      To get started, you will first need to setup an incoming webhook.
      Go to, https://`your_team_name`.slack.com/services/new/incoming-webhook,
      choose a default channel and add the integration.

      Your webhook URL will look like:

      https://`your_team_name`.slack.com/services/hooks/incoming-webhook?token=`your_auth_token`

      Once the webhook has been setup it can be used to post to other channels or ping team members.
      To send a private message to team-mate, assign his username as `@username` to the channel option.
      To communicate with a different webhook on slack, assign your custom webhook name to the webhook option.
      Messages can also be formatted using [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid)
    MD

    def default_options
      {
        'team_name' => 'your_team_name',
        'auth_token' => 'your_auth_token',
        'channel' => '#general',
        'username' => DEFAULT_USERNAME,
        'message' => "Hey there, It's Huginn",
        'webhook' => DEFAULT_WEBHOOK
      }
    end

    def validate_options
      errors.add(:base, "auth_token is required") unless options['auth_token'].present?
      errors.add(:base, "team_name is required") unless options['team_name'].present?
      errors.add(:base, "channel is required") unless options['channel'].present?
    end

    def working?
      received_event_without_error?
    end

    def webhook
      options[:webhook].presence || DEFAULT_WEBHOOK
    end

    def username
      options[:username].presence || DEFAULT_USERNAME
    end

    def slack_notifier
      @slack_notifier ||= Slack::Notifier.new(options[:team_name], options[:auth_token], webhook, username: username)
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        opts = interpolate_options options, event.payload
        slack_notifier.ping opts[:message], channel: opts[:channel], username: opts[:username]
      end
    end
  end
end
