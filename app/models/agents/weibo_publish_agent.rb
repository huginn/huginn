# encoding: utf-8 
require "weibo_2"

module Agents
  class WeiboPublishAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The WeiboPublishAgent publishes tweets from the events it receives.

      You must first set up a Weibo app and generate an `acess_token` for the user to send statuses as.

      Include that in options, along with the `app_key` and `app_secret` for your Weibo app. It's useful to also include the Weibo user id of the person to publish as.

      You must also specify a `message_path` parameter: a [JSONPaths](http://goessner.net/articles/JsonPath/) to the value to tweet.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    def validate_options
      unless options[:uid].present? &&
        options[:expected_update_period_in_days].present? &&
        options[:app_key].present? &&
        options[:app_secret].present? &&
        options[:access_token].present?
        errors.add(:base, "expected_update_period_in_days, uid, and access_token are required")
      end
    end

    def working?
      (event = event_created_within(options[:expected_update_period_in_days].to_i.days)) && event.payload.present? && event.payload[:success] == true
    end

    def default_options
      {
          :uid => "",
          :access_token => "---",
          :app_key => "---",
          :app_secret => "---",
          :expected_update_period_in_days => "10",
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
        if event.agent.type == "Agents::TwitterUserAgent"
          tweet_text = unwrap_tco_urls(tweet_text, event.payload)
        end
        begin
          publish_tweet tweet_text
          create_event :payload => {
            :success => true,
            :published_tweet => tweet_text,
            :agent_id => event.agent_id,
            :event_id => event.id
          }
        rescue OAuth2::Error => e
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
      WeiboOAuth2::Config.api_key = options[:app_key] # WEIBO_APP_KEY
      WeiboOAuth2::Config.api_secret = options[:app_secret] # WEIBO_APP_SECRET
      client = WeiboOAuth2::Client.new
      client.get_token_from_hash :access_token => options[:access_token]

      client.statuses.update text
    end

    def unwrap_tco_urls text, tweet_json
      tweet_json[:entities][:urls].each do |url|
        text.gsub! url[:url], url[:expanded_url]
      end
      return text
    end

  end
end