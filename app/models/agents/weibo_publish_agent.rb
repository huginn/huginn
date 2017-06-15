# encoding: utf-8

module Agents
  class WeiboPublishAgent < Agent
    include WeiboConcern

    cannot_be_scheduled!

    description <<-MD
      The Weibo Publish Agent publishes tweets from the events it receives.

      #{'## Include `weibo_2` in your Gemfile to use this Agent!' if dependencies_missing?}

      You must first set up a Weibo app and generate an `access_token` for the user that will be used for posting status updates.

      You'll use that `access_token`, along with the `app_key` and `app_secret` for your Weibo app. You must also include the Weibo User ID (as `uid`) of the person to publish as.

      You must also specify a `message_path` parameter: a [JSONPaths](http://goessner.net/articles/JsonPath/) to the value to tweet.

      You can also specify a `pic_path` parameter: a [JSONPaths](http://goessner.net/articles/JsonPath/) to the picture url to tweet along.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    def validate_options
      unless options['uid'].present? &&
             options['expected_update_period_in_days'].present?
        errors.add(:base, "expected_update_period_in_days and uid are required")
      end
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'uid' => "",
        'access_token' => "---",
        'app_key' => "---",
        'app_secret' => "---",
        'expected_update_period_in_days' => "10",
        'message_path' => "text",
        'pic_path' => "pic"
      }
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      if incoming_events.count > 20
        incoming_events = incoming_events.first(20)
      end
      incoming_events.each do |event|
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
          create_event :payload => {
            'success' => true,
            'published_tweet' => tweet_text,
            'published_pic' => pic_url,
            'agent_id' => event.agent_id,
            'event_id' => event.id
          }
        rescue OAuth2::Error => e
          create_event :payload => {
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

    def publish_tweet text
      weibo_client.statuses.update text
    end

    def publish_tweet_with_pic text, pic
      weibo_client.statuses.upload text, open(pic)
    end

    def valid_image?(url)
      begin
        url = URI.parse(url)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == "https")
        http.start do |http|
          # images supported #http://open.weibo.com/wiki/2/statuses/upload
          return ['image/gif', 'image/jpeg', 'image/png'].include? http.head(url.request_uri)['Content-Type']
        end
      rescue => e
        return false
      end
    end

    def unwrap_tco_urls text, tweet_json
      tweet_json[:entities][:urls].each do |url|
        text.gsub! url[:url], url[:expanded_url]
      end
      text
    end
  end
end
