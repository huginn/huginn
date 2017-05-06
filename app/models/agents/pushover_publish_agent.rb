require "net/http"
require "uri"

module Agents
  class PushoverPublishAgent < Agent
    cannot_be_scheduled!

    description <<-MD
The PushoverPublishAgent sends received events to [Pushover](https://pushover.net/) clients on your devices.

Because Pushover has free limit of 7500 messages per application per month, to use this agent you must [set up](https://pushover.net/apps/build) your own Pushover Application and obtain unique API key.

Agent needs the following mandatory parameters to work:

*   `api_token` - Pushover API token of application that you have set up 
*   `user_key` - your User Key
*   `message_path` - [JSONPath](http://goessner.net/articles/JsonPath/) to the message text in the event
*   `expected_receive_period_in_days` - to the maximum amount of time that you'd expect to pass between Events being consumed by this Agent

Also you may add the following optional parameters:

*   `device` - your user's device name to send the message directly to that device, rather than all of the user's devices
*   `title_path` - [JSONPath](http://goessner.net/articles/JsonPath/) to your message's title, otherwise your registered Pushover app's name will be used
*   `url_path` - [JSONPath](http://goessner.net/articles/JsonPath/) to a supplementary URL to show with your message
*   `url_title_path` - [JSONPath](http://goessner.net/articles/JsonPath/) to a title for your supplementary URL, otherwise just the URL is shown
*   `priority` - set to -1 to always send as a quiet notification, 0 to send as notmal notification, 1 to display as [high-priority](https://pushover.net/api#priority) and bypass the user's quiet hours, or 2 to also require confirmation from the user
*   `retry` - if `priority` is set to 2, this parameter should be passed to specify how often (in seconds) the Pushover servers will send the same notification to the user
*   `expiry` - if `priority` is set to 2, this parameter should be passed to specify how many seconds your notification will continue to be retried for (every `retry` seconds)
*   `sound` - the name of one of the [sounds](https://pushover.net/api#sounds) supported by device clients to override the user's default sound choice
    MD

    def validate_options
      unless options[:expected_receive_period_in_days].present? &&
        options[:api_token].present? &&
        options[:user_key].present?
        errors.add(:base, "expected_receive_period_in_days, api_token, user_key are required")
      end
    end

    def working?
      last_receive_at && last_receive_at > options[:expected_receive_period_in_days].to_i.days.ago
    end

    def default_options
      {
        :expected_receive_period_in_days => "10",
        :api_token => "",
        :user_key => "",
        :message_path => "text",
        :title_path => "title",
        :url_path => "url",
        :url_title_path => "",
        :priority => "0",
        :sound => "pushover"
      }
    end

    def receive(events)
      uri = URI("https://api.pushover.net/1/messages.json")
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == "https") do |http|
        events.each do |event|
          request = Net::HTTP::Post.new(uri.request_uri)
          post_data = {
            :token => options[:api_token],
            :user => options[:user_key],
            :message => Utils.value_at(event.payload, options[:message_path])
          }
          if options.has_key?(:title_path) then
            post_data[:title] = Utils.value_at(event.payload, options[:title_path])
          end
          if options.has_key?(:url_path) then
            post_data[:url] = Utils.value_at(event.payload, options[:url_path])
          end
          if options.has_key?(:url_title_path) then
            post_data[:url_title] = Utils.value_at(event.payload, options[:url_title_path])
          end
          if options.has_key?(:priority) then
            post_data[:priority] = options[:priority]
          end
          if options.has_key?(:sound) then
            post_data[:sound] = options[:sound]
          end
          request.set_form_data(post_data)
          Rails.logger.debug "PushoverPublishAgent: request: #{request.body}"
          response = http.request(request)
          Rails.logger.debug "PushoverPublishAgent: response: #{response.code} #{response.body}"
        end
      end
    end
  end
end
