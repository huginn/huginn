module Agents
  class TwitterUserAgent < Agent
    include TwitterConcern

    cannot_receive_events!

    description <<-MD
      The Twitter User Agent either follows the timeline of a specific Twitter user or follows your own home timeline including both your tweets and tweets from people whom you are following.

      #{twitter_dependencies_missing if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Twitter in the [Services](/services) section first.

      To follow a Twitter user set `choose_home_time_line` to `false` and provide the `username`.

      To follow your own home timeline set `choose_home_time_line` to `true`.

      Set `include_retweets` to `false` to not include retweets (default: `true`)
      
      Set `exclude_replies` to `true` to exclude replies (default: `false`)

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Set `starting_at` to the date/time (eg. `Mon Jun 02 00:38:12 +0000 2014`) you want to start receiving tweets from (default: agent's `created_at`)
    MD

    event_description <<-MD
      Events are the raw JSON provided by the [Twitter API](https://dev.twitter.com/docs/api/1.1/get/statuses/user_timeline). Should look something like:
          {
             ... every Tweet field, including ...
            "full_text": "something",
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

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'username' => 'tectonic',
        'include_retweets' => 'true',
        'exclude_replies' => 'false',
        'expected_update_period_in_days' => '2',
        'choose_home_time_line' => 'false'
      }
    end

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
      errors.add(:base, "username is required") if options['username'].blank? && !boolify(options['choose_home_time_line'])

      if options[:include_retweets].present? && !%w[true false].include?(options[:include_retweets])
        errors.add(:base, "include_retweets must be a boolean value string (true/false)")
      end

      if options[:starting_at].present?
        Time.parse(options[:starting_at]) rescue errors.add(:base, "Error parsing starting_at")
      end
    end

    def starting_at
      if interpolated[:starting_at].present?
        Time.parse(interpolated[:starting_at]) rescue created_at
      else
        created_at
      end
    end

    def choose_home_time_line?
      boolify(interpolated['choose_home_time_line'])
    end

    def include_retweets?
      interpolated[:include_retweets] != "false"
    end
    
    def exclude_replies?
      boolify(interpolated[:exclude_replies]) || false
    end

    def check
      since_id = memory['since_id'] || nil
      opts = {:count => 200, :include_rts => include_retweets?, :exclude_replies => exclude_replies?, :include_entities => true, :contributor_details => true, tweet_mode: 'extended'}
      opts.merge! :since_id => since_id unless since_id.nil?

      if choose_home_time_line?
        tweets = twitter.home_timeline(opts)
      else
        tweets = twitter.user_timeline(interpolated['username'], opts)
      end

      tweets.each do |tweet|
        if tweet.created_at >= starting_at
          memory['since_id'] = tweet.id if !memory['since_id'] || (tweet.id > memory['since_id'])

          create_event :payload => tweet.attrs
        end
      end
    end
  end
end
