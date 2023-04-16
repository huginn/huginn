module Agents
  class TwitterUserAgent < Agent
    include TwitterConcern

    can_dry_run!
    cannot_receive_events!

    description <<~MD
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

    event_description <<~MD
      Events are the raw JSON provided by the [Twitter API v1.1](https://dev.twitter.com/docs/api/1.1/get/statuses/user_timeline) with slight modifications.  They should look something like this:

      #{tweet_event_description('full_text')}
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
      if options[:expected_update_period_in_days].blank?
        errors.add(:base, "expected_update_period_in_days is required")
      end

      if !boolify(options[:choose_home_time_line]) && options[:username].blank?
        errors.add(:base, "username is required")
      end

      if options[:include_retweets].present? && !%w[true false].include?(options[:include_retweets].to_s)
        errors.add(:base, "include_retweets must be a boolean value (true/false)")
      end

      if options[:starting_at].present?
        begin
          Time.parse(options[:starting_at])
        rescue StandardError
          errors.add(:base, "Error parsing starting_at")
        end
      end
    end

    def check
      opts = {
        count: 200,
        include_rts: include_retweets?,
        exclude_replies: exclude_replies?,
        include_entities: true,
        contributor_details: true,
        tweet_mode: 'extended',
        since_id: memory[:since_id].presence,
      }.compact

      tweets =
        if choose_home_time_line?
          twitter.home_timeline(opts)
        else
          twitter.user_timeline(interpolated[:username], opts)
        end

      tweets.sort_by(&:id).each do |tweet|
        next unless tweet.created_at >= starting_at

        memory[:since_id] = [tweet.id, *memory[:since_id]].max

        create_event(payload: format_tweet(tweet))
      end
    end

    private

    def starting_at
      if interpolated[:starting_at].present?
        begin
          Time.parse(interpolated[:starting_at])
        rescue StandardError
        end
      end || created_at || Time.now # for dry-running
    end

    def choose_home_time_line?
      boolify(interpolated[:choose_home_time_line])
    end

    def include_retweets?
      # default to true
      boolify(interpolated[:include_retweets]) != false
    end

    def exclude_replies?
      # default to false
      boolify(interpolated[:exclude_replies]) || false
    end
  end
end
