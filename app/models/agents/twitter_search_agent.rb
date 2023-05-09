module Agents
  class TwitterSearchAgent < Agent
    include TwitterConcern

    can_dry_run!
    cannot_receive_events!

    description <<~MD
      The Twitter Search Agent performs and emits the results of a specified Twitter search.

      #{twitter_dependencies_missing if dependencies_missing?}

      If you want realtime data from Twitter about frequent terms, you should definitely use the Twitter Stream Agent instead.

      To be able to use this Agent you need to authenticate with Twitter in the [Services](/services) section first.

      You must provide the desired `search`.

      Set `result_type` to specify which [type of search results](https://dev.twitter.com/rest/reference/get/search/tweets) you would prefer to receive. Options are "mixed", "recent", and "popular". (default: `mixed`)

      Set `max_results` to limit the amount of results to retrieve per run(default: `500`. The API rate limit is ~18,000 per 15 minutes. [Click here to learn more about rate limits](https://dev.twitter.com/rest/public/rate-limiting).

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Set `starting_at` to the date/time (eg. `Mon Jun 02 00:38:12 +0000 2014`) you want to start receiving tweets from (default: agent's `created_at`)
    MD

    event_description <<~MD
      Events are the raw JSON provided by the [Twitter API v1.1](https://developer.twitter.com/en/docs/twitter-api/v1/tweets/search/api-reference/get-search-tweets) with slight modifications.  They should look something like this:

      #{tweet_event_description('full_text')}
    MD

    default_schedule "every_1h"

    def working?
      event_created_within?(interpolated[:expected_update_period_in_days]) && !recent_error_logs?
    end

    def default_options
      {
        'search' => 'freebandnames',
        'expected_update_period_in_days' => '2'
      }
    end

    def validate_options
      if options[:search].blank?
        errors.add(:base, "search is required")
      end

      if options[:expected_update_period_in_days].blank?
        errors.add(:base, "expected_update_period_in_days is required")
      end

      if options[:starting_at].present?
        begin
          Time.parse(interpolated[:starting_at])
        rescue StandardError
          errors.add(:base, "Error parsing starting_at")
        end
      end
    end

    def starting_at
      if interpolated[:starting_at].present?
        begin
          Time.parse(interpolated[:starting_at])
        rescue StandardError
        end
      end || created_at || Time.now # for dry-running
    end

    def max_results
      (interpolated[:max_results].presence || 500).to_i
    end

    def check
      opts = {
        include_entities: true,
        tweet_mode: 'extended',
        result_type: interpolated[:result_type].presence,
        since_id: memory[:since_id].presence,
      }.compact

      # http://www.rubydoc.info/gems/twitter/Twitter/REST/Search
      tweets = twitter.search(interpolated[:search], opts).take(max_results)

      tweets.each do |tweet|
        next unless tweet.created_at >= starting_at

        memory[:since_id] = [tweet.id, *memory[:since_id]].max

        create_event(payload: format_tweet(tweet))
      end

      save!
    end
  end
end
