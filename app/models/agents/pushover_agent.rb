module Agents
  class PushoverAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!


    API_URL = 'https://api.pushover.net/1/messages.json'

    description <<-MD
      The Pushover Agent receives and collects events and sends them via push notification to a user/group.

      **You need a Pushover API Token:** [https://pushover.net/apps/build](https://pushover.net/apps/build)

      **You must provide** a `message` or `text` key that will contain the body of the notification. This can come from an event or be set as a default. Pushover API has a `512` Character Limit including `title`. `message` will be truncated.

      * `token`: your application's API token
      * `user`: the user or group key (not e-mail address).
      * `expected_receive_period_in_days`:  is maximum number of days that you would expect to pass between events being received by this agent.

      Your event can provide any of the following optional parameters or you can provide defaults:

      * `device` - your user's device name to send the message directly to that device, rather than all of the user's devices
      * `title` or `subject` - your notification's title
      * `url` - a supplementary URL to show with your message - `512` Character Limit
      * `url_title` - a title for your supplementary URL, otherwise just the URL is shown - `100` Character Limit
      * `priority` - send as `-1` to always send as a quiet notification, `0` is default, `1` to display as high-priority and bypass the user's quiet hours, or `2` for emergency priority: [Please read Pushover Docs on Emergency Priority](https://pushover.net/api#priority)
      * `sound` - the name of one of the sounds supported by device clients to override the user's default sound choice. [See PushOver docs for sound options.](https://pushover.net/api#sounds)
      * `retry` - Required for emergency priority - Specifies how often (in seconds) the Pushover servers will send the same notification to the user. Minimum value: `30`
      * `expire` - Required for emergency priority - Specifies how many seconds your notification will continue to be retried for (every retry seconds). Maximum value: `86400`

      Your event can also pass along a timestamp parameter:

      * `timestamp` - a [Unix timestamp](https://en.wikipedia.org/wiki/Unix_time) of your message's date and time to display to the user, rather than the time your message is received by the Pushover API.

    MD

    def default_options
      {
        'token' => '',
        'user' => '',
        'message' => 'a default message',
        'device' => '',
        'title' => '',
        'url' => '',
        'url_title' => '',
        'priority' => '0',
        'sound' => 'pushover',
        'retry' => '0',
        'expire' => '0',
        'expected_receive_period_in_days' => '1'
      }
    end

    def validate_options
      unless options['token'].present? && options['user'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, 'token, user, and expected_receive_period_in_days are all required.')
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload_interpolated = interpolated(event)
        message = (event.payload['message'].presence || event.payload['text'].presence || payload_interpolated['message']).to_s
        if message.present?
          post_params = {
            'token' => payload_interpolated['token'],
            'user' => payload_interpolated['user'],
            'message' => message
          }

          post_params['device'] = event.payload['device'].presence || payload_interpolated['device']
          post_params['title'] = event.payload['title'].presence || event.payload['subject'].presence || payload_interpolated['title']

          url = (event.payload['url'].presence || payload_interpolated['url'] || '').to_s
          url = url.slice 0..512
          post_params['url'] = url

          url_title = (event.payload['url_title'].presence || payload_interpolated['url_title']).to_s
          url_title = url_title.slice 0..100
          post_params['url_title'] = url_title

          post_params['priority'] = (event.payload['priority'].presence || payload_interpolated['priority']).to_i

          if event.payload.has_key? 'timestamp'
            post_params['timestamp'] = (event.payload['timestamp']).to_s
          end

          post_params['sound'] = (event.payload['sound'].presence || payload_interpolated['sound']).to_s

          post_params['retry'] = (event.payload['retry'].presence || payload_interpolated['retry']).to_i

          post_params['expire'] = (event.payload['expire'].presence || payload_interpolated['expire']).to_i

          send_notification(post_params)
        end
      end
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def send_notification(post_params)
      response = HTTParty.post(API_URL, :query => post_params)
      puts response
    end
  end
end
