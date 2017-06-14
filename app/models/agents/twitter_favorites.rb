module Agents
  class TwitterFavorites < Agent
    include TwitterConcern

    cannot_receive_events!

    description <<-MD
      The Twitter Favorites List Agent follows the favorites list of a specified Twitter user.

      #{twitter_dependencies_missing if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Twitter in the [Services](/services) section first.

      You must also provide the `username` of the Twitter user, `number` of latest tweets to monitor and `history' as number of tweets that will be held in memory.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
      
      Set `starting_at` to the date/time (eg. `Mon Jun 02 00:38:12 +0000 2014`) you want to start receiving tweets from (default: agent's `created_at`)
    MD

    event_description <<-MD
      Events are the raw JSON provided by the [Twitter API](https://dev.twitter.com/docs/api/1.1/get/favorites/list). Should look something like:
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

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'username' => 'tectonic',
        'number' => '10',
        'history' => '100',
        'expected_update_period_in_days' => '2'
      }
    end

     def validate_options
      errors.add(:base, "username is required") unless options['username'].present?
      errors.add(:base, "number is required") unless options['number'].present?
      errors.add(:base, "history is required") unless options['history'].present?
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?

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

    def check
      opts = {:count => interpolated['number'], tweet_mode: 'extended'}
      tweets = twitter.favorites(interpolated['username'], opts)
      memory[:last_seen] ||= []

      tweets.each do |tweet|
        unless memory[:last_seen].include?(tweet.id) || tweet.created_at < starting_at
          memory[:last_seen].push(tweet.id)
          memory[:last_seen].shift if memory[:last_seen].length > interpolated['history'].to_i
          create_event payload: tweet.attrs
        end
      end
    end
  end
end
