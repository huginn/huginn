module Agents
  class TwitterStreamAgent < Agent
    include TwitterConcern

    cannot_receive_events!

    description <<-MD
      The TwitterStreamAgent follows the Twitter stream in real time, watching for certain keywords, or filters, that you provide.

      To follow the Twitter stream, provide an array of `filters`.  Multiple words in a filter must all show up in a tweet, but are independent of order.
      If you provide an array instead of a filter, the first entry will be considered primary and any additional values will be treated as aliases.

      Twitter credentials must be supplied as either [credentials](/user_credentials) called
      `twitter_consumer_key`, `twitter_consumer_secret`, `twitter_oauth_token`, and `twitter_oauth_token_secret`,
      or as options to this Agent called `consumer_key`, `consumer_secret`, `oauth_token`, and `oauth_token_secret`.

      To get oAuth credentials for Twitter, [follow these instructions](https://github.com/cantino/huginn/wiki/Getting-a-twitter-oauth-token).

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      `generate` should be either `events` or `counts`.  If set to `counts`, it will output event summaries whenever the Agent is scheduled.
    MD

    event_description <<-MD
      When in `counts` mode, TwitterStreamAgent events look like:

          {
            "filter": "hello world",
            "count": 25,
            "time": 3456785456
          }

      When in `events` mode, TwitterStreamAgent events look like:

          {
            "filter": "selectorgadget",
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

    default_schedule "11pm"

    def validate_options
      unless options['filters'].present? &&
             options['expected_update_period_in_days'].present? &&
             options['generate'].present?
        errors.add(:base, "expected_update_period_in_days, generate, and filters are required fields")
      end
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'filters' => %w[keyword1 keyword2],
        'expected_update_period_in_days' => "2",
        'generate' => "events"
      }
    end

    def process_tweet(filter, status)
      filter = lookup_filter(filter)

      if filter
        if options['generate'] == "counts"
          # Avoid memory pollution by reloading the Agent.
          agent = Agent.find(id)
          agent.memory['filter_counts'] ||= {}
          agent.memory['filter_counts'][filter] ||= 0
          agent.memory['filter_counts'][filter] += 1
          remove_unused_keys!(agent, 'filter_counts')
          agent.save!
        else
          create_event :payload => status.merge('filter' => filter)
        end
      end
    end

    def check
      if options['generate'] == "counts" && memory['filter_counts'] && memory['filter_counts'].length > 0
        memory['filter_counts'].each do |filter, count|
          create_event :payload => { 'filter' => filter, 'count' => count, 'time' => Time.now.to_i }
        end
      end
      memory['filter_counts'] = {}
    end

    protected

    def lookup_filter(filter)
      options['filters'].each do |known_filter|
        if known_filter == filter
          return filter
        elsif known_filter.is_a?(Array)
          if known_filter.include?(filter)
            return known_filter.first
          end
        end
      end
    end

    def remove_unused_keys!(agent, base)
      if agent.memory[base]
        (agent.memory[base].keys - agent.options['filters'].map {|f| f.is_a?(Array) ? f.first.to_s : f.to_s }).each do |removed_key|
          agent.memory[base].delete(removed_key)
        end
      end
    end
  end
end