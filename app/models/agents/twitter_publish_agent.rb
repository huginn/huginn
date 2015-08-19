module Agents
  class TwitterPublishAgent < Agent
    include TwitterConcern

    cannot_be_scheduled!

    description <<-MD
      The Twitter Publish Agent publishes tweets from the events it receives.

      #{twitter_dependencies_missing if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Twitter in the [Services](/services) section first.

      You must also specify a `message` parameter, you can use [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) to format the message.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => "10",
        'message' => "{{text}}"
      }
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      if incoming_events.count > 20
        incoming_events = incoming_events.first(20)
      end
      incoming_events.each do |event|
        tweet_text = interpolated(event)['message']
        begin
          tweet = publish_tweet tweet_text
          create_event :payload => {
            'success' => true,
            'published_tweet' => tweet_text,
            'tweet_id' => tweet.id,
            'agent_id' => event.agent_id,
            'event_id' => event.id
          }
        rescue Twitter::Error => e
          create_event :payload => {
            'success' => false,
            'error' => e.message,
            'failed_tweet' => tweet_text,
            'agent_id' => event.agent_id,
            'event_id' => event.id
          }
        end
      end
    end

    def publish_tweet(text)
      twitter.update(text)
    end
  end
end
