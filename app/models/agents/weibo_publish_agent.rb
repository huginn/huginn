require "open-uri"

module Agents
  class WeiboPublishAgent < Agent
    include WeiboConcern

    cannot_be_scheduled!

    description <<~MD
      The Weibo Publish Agent publishes posts from the events it receives.

      You must first set up a Weibo app and generate an `access_token` for the user that will be used for posting status updates.

      You must also specify a `message_path` parameter: a [JSONPaths](http://goessner.net/articles/JsonPath/) to the value to publish.

      You can also specify a `pic_path` parameter: a [JSONPaths](http://goessner.net/articles/JsonPath/) to the picture url to publish along.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options["expected_update_period_in_days"].present?
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'access_token' => "---",
        'expected_update_period_in_days' => "10",
        'message_path' => "text",
        'pic_path' => "pic"
      }
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      incoming_events.first(20).each do |event|
        tweet_text = Utils.value_at(event.payload, interpolated(event)['message_path'])
        pic_url = Utils.value_at(event.payload, interpolated(event)['pic_path'])
        if event.agent.type == "Agents::TwitterUserAgent"
          tweet_text = unwrap_tco_urls(tweet_text, event.payload)
        end
        begin
          if valid_image?(pic_url)
            publish_tweet_with_pic tweet_text, pic_url
          else
            publish_tweet tweet_text
          end
          create_event payload: {
            'success' => true,
            'published_tweet' => tweet_text,
            'published_pic' => pic_url,
            'agent_id' => event.agent_id,
            'event_id' => event.id
          }
        rescue Faraday::Error => e
          create_event payload: {
            'success' => false,
            'error' => e.message,
            'failed_tweet' => tweet_text,
            'failed_pic' => pic_url,
            'agent_id' => event.agent_id,
            'event_id' => event.id
          }
        end
        # you can't tweet too fast, give it a minute, i mean... 10 seconds
        sleep 10 if incoming_events.length > 1
      end
    end

    def publish_tweet(text)
      weibo_client.statuses.update text
    end

    def publish_tweet_with_pic(text, pic)
      url = Utils.normalize_uri(pic)
      raise ArgumentError, "invalid picture URL" unless url.is_a?(URI::HTTP)

      url.open do |image|
        weibo_client.statuses.upload text, image, content_type: image.content_type
      end
    end

    def valid_image?(url)
      return false if url.blank?

      url = Utils.normalize_uri(url)
      return false unless url.is_a?(URI::HTTP)

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")
      http.start do |http|
        # images supported #http://open.weibo.com/wiki/2/statuses/upload
        return ['image/gif', 'image/jpeg', 'image/png'].include? http.head(url.request_uri)['Content-Type']
      end
    rescue StandardError
      false
    end

    def unwrap_tco_urls(text, tweet_json)
      tweet_json[:entities][:urls].each do |url|
        text.gsub! url[:url], url[:expanded_url]
      end
      text
    end
  end
end
