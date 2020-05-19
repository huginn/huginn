module Agents
  class SlackAgent < Agent
    DEFAULT_USERNAME = 'Huginn'
    ALLOWED_PARAMS = ['attachments', 'blocks']

    can_dry_run!
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    gem_dependency_check { defined?(Slack) }

    description <<-MD
      The Slack Agent lets you receive events and send notifications to [Slack](https://slack.com/).

      #{'## Include `slack-notifier` in your Gemfile to use this Agent!' if dependencies_missing?}

      To get started, you will first need to configure an incoming webhook.

      - Go to `https://my.slack.com/services/new/incoming-webhook`, choose the channel and add the integration.
      - *Notes*:
        - You can no longer change the channel to which your Agent will post.
        - The custom icon can no longer be specified.

      Your webhook URL will look like: `https://hooks.slack.com/services/some/random/characters`

      Once the webhook has been configured, it can be used to post only to the channel specified when it was created. Messages can be formatted using [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid).

      You can also add `attachments` and/or `blocks` to your message. See the [Slack webhook docs](https://api.slack.com/messaging/webhooks#advanced_message_formatting) for more info.
    MD

    def default_options
      {
        'webhook_url' => 'https://hooks.slack.com/services/...',
        'message' => "Hey there, It's Huginn",
      }
    end

    def validate_options
      unless options['webhook_url'].present? # Now the only option usable in Slack
        errors.add(:base, "webhook_url is required")
      end
    end

    def working?
      received_event_without_error?
    end

    def webhook_url
      case
      when url = interpolated[:webhook_url].presence
        url
      end
    end

    def slack_notifier
      @slack_notifier ||= Slack::Notifier.new(webhook_url)
    end

    def filter_options(opts)
      opts.select { |key, value| ALLOWED_PARAMS.include? key }.symbolize_keys
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        opts = interpolated(event)
        slack_opts = filter_options(opts)
        slack_notifier.ping opts[:message], slack_opts
      end
    end
  end
end
