require "twitter"

module Agents
  class TwitterPublishAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The TwitterPublishAgent publishes tweets from the events it receives.

      You [must set up a Twitter app](https://github.com/cantino/huginn/wiki/Getting-a-twitter-oauth-token) and provide it's `consumer_key`, `consumer_secret`, `oauth_token` and `oauth_token_secret`,
      (also knows as "Access token" on the Twitter developer's site), along with the `username` of the Twitter user to publish as.

      The `oauth_token` and `oauth_token_secret` determine which user the tweet will be sent as.

      You must also specify a `message_path` parameter: a [JSONPaths](http://goessner.net/articles/JsonPath/) to the value to tweet.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    def validate_options
      unless options[:username].present? &&
        options[:expected_update_period_in_days].present? &&
        options[:consumer_key].present? &&
        options[:consumer_secret].present? &&
        options[:oauth_token].present? &&
        options[:oauth_token_secret].present?
        errors.add(:base, "expected_update_period_in_days, username, consumer_key, consumer_secret, oauth_token and oauth_token_secret are required")
      end
    end

    def working?
      (event = event_created_within(options[:expected_update_period_in_days].to_i.days)) && event.payload.present? && event.payload[:success] == true
    end

    def default_options
      {
          :username => "",
          :expected_update_period_in_days => "10",
          :consumer_key => "---",
          :consumer_secret => "---",
          :oauth_token => "---",
          :oauth_token_secret => "---",
          :message_path => "text"
      }
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      if incoming_events.count > 20
        incoming_events = incoming_events.first(20)
      end
      incoming_events.each do |event|
        tweet_text = Utils.value_at(event.payload, options[:message_path])
        begin
          publish_tweet tweet_text
          create_event :payload => {
            :success => true,
            :published_tweet => tweet_text,
            :agent_id => event.agent_id,
            :event_id => event.id
          }
        rescue Twitter::Error => e
          create_event :payload => {
            :success => false,
            :error => e.message,
            :failed_tweet => tweet_text,
            :agent_id => event.agent_id,
            :event_id => event.id
          }
        end
      end
    end

    def publish_tweet text
      Twitter.configure do |config|
        config.consumer_key = options[:consumer_key]
        config.consumer_secret = options[:consumer_secret]
        config.oauth_token = options[:oauth_token]
        config.oauth_token_secret = options[:oauth_token_secret]
      end

      Twitter.update(text)
    end

  end
end