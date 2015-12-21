module Agents
  class TwitterRetweetAgent < Agent
    include TwitterConcern

    cannot_be_scheduled!

    description <<-MD
      The Twitter Retweet Agent retweets tweets from the events it receives. It expects to consume events generated by twitter agents where the payload is a hash of tweet information. The existing TwitterStreamAgent is one example of a valid event producer for this Agent.

      #{ twitter_dependencies_missing if dependencies_missing? }

      To be able to use this Agent you need to authenticate with Twitter in the [Services](/services) section first.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    def validate_options
      errors.add(:base, "expected_receive_period_in_days is required") unless options['expected_receive_period_in_days'].present?
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def default_options
      {
        'expected_receive_period_in_days' => "2",
      }
    end

    def receive(incoming_events)
      tweets_to_retweet = tweets_from_events(incoming_events)

      begin
        twitter.retweet(tweets_to_retweet)
      rescue Twitter::Error => e
        create_event :payload => {
          'success' => false,
          'error' => e.message,
          'tweets' => Hash[tweets_to_retweet.map { |t| [t.id, t.text] }],
          'agent_ids' => incoming_events.map(&:agent_id),
          'event_ids' => incoming_events.map(&:id)
        }
      end
    end

    def tweets_from_events(events)
      events.map do |e|
        Twitter::Tweet.new(id: e.payload["id"], text: e.payload["text"])
      end
    end
  end
end

