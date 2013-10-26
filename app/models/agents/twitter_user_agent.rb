require "twitter"

module Agents
  class TwitterUserAgent < Agent
    include TwitterConcern

    cannot_receive_events!

    description <<-MD
      The TwitterUserAgent follows the timeline of a specified Twitter user.

      You [must set up a Twitter app](https://github.com/cantino/huginn/wiki/Getting-a-twitter-oauth-token) and provide it's `consumer_key`, `consumer_secret`, `oauth_token` and `oauth_token_secret`, (Also shown as "Access token" on the Twitter developer's site.) along with the `username` of the Twitter user to monitor.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    event_description <<-MD
      Events are the raw JSON provided by the Twitter API. Should look something like:

          {
             ... every Tweet field, including ...
            "text": "something",
            "user": {
              "name": "Mr. Someone",
              "screen_name": "Someone",
              "location": "Vancouver BC Canada",
              "description":  "...",
              "followers_count": 486,
              "friends_count": 1983,
              "created_at": "Mon Aug 29 23:38:14 +0000 2011",
              "time_zone": "Pacific Time (US & Canada)",
              "statuses_count": 3807,
              "lang": "en"
            },
            "retweet_count": 0,
            "entities": ...
            "lang": "en"
          }
    MD

    default_schedule "every_1h"

    def validate_options
      unless options[:username].present? &&
        options[:expected_update_period_in_days].present?
        errors.add(:base, "username and expected_update_period_in_days are required")
      end      
    end

    def working?
      event_created_within(options[:expected_update_period_in_days]) && !recent_error_logs?
    end

    def default_options
      {
          :username => "tectonic",
          :expected_update_period_in_days => "2",
          :consumer_key => "---",
          :consumer_secret => "---",
          :oauth_token => "---",
          :oauth_token_secret => "---"
      }
    end

    def check
      since_id = memory[:since_id] || nil
      opts = {:count => 200, :include_rts => true, :exclude_replies => false, :include_entities => true, :contributor_details => true}
      opts.merge! :since_id => since_id unless since_id.nil?

      tweets = Twitter.user_timeline(options[:username], opts)

      tweets.each do |tweet|
        memory[:since_id] = tweet.id if !memory[:since_id] || (tweet.id > memory[:since_id])

        create_event :payload => tweet.attrs
      end

      save!
    end
  end
end