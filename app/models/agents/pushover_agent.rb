
module Agents
  class PushoverAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The PushoverAgent receives and collects events and sends them via push notification to a user/group.

      You need a Pushover API Token: [https://pushover.net/apps/build](https://pushover.net/apps/build)

      * `token`: your application's API token
      * `user`: the user or group key (not e-mail address).
      * `expected_receive_period_in_days`:  is maximum number of days that you would expect to pass between events being received by this agent.
      
      Your event should provide a `message` or `text` key that will contain the body of the notification. Pushover API has a `512` Character Limit including title. 

      Your event can provide any of the following optional parameters or you can provide defaults:

      * `device` - your user's device name to send the message directly to that device, rather than all of the user's devices
      * `title` or `subject` - your notifications's title
      * `url` - a supplementary URL to show with your message - `512` Character Limit
      * `url_title` - a title for your supplementary URL, otherwise just the URL is shown - `100` Character Limit
      * `priority` - send as -1 to always send as a quiet notification, 1 to display as high-priority and bypass the user's quiet hours, or 2 to also require confirmation from the user
      * `timestamp` - a [Unix timestamp](https://en.wikipedia.org/wiki/Unix_time) of your message's date and time to display to the user, rather than the time your message is received by our API
      * `sound` - the name of one of the sounds supported by device clients to override the user's default sound choice


    MD

    def default_options
      {
        'token' => 'vKxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'user' => 'Fjxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'device' => '',
        'title' => '',
        'url' => '',
        'url_title' => '',
        'priority' => '0',
        'timestamp' => '',
        'sound' => 'pushover',
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
        message = (event.payload['message'] || event.payload['text']).to_s
        if message != ""
            post_params = {
              'token' => options['token'],
              'user' => options['user'],
              'message' => message
            }

            if event.payload['device'] || options['device']
              post_params['device'] = event.payload['device'] || options['device']
            end

            if event.payload['title'] || options['title']
              post_params['title'] = event.payload['title'] || options['title']
            end

            if event.payload['url'] || options['url']
              url = (event.payload['url'] || options['url'] || '').to_s
              url = url.slice 0..512
              post_params['url'] = url
            end

            if event.payload['url_title'] || options['url_title']
              url_title = (event.payload['url_title'] || options['url_title']).to_s
              url_title = url_title.slice 0..100
              post_params['url_title'] = url_title
            end

            if event.payload['priority'] || options['priority']
              post_params['priority'] = (event.payload['priority'] || options['priority']).to_i
            end

            if event.payload['timestamp'] || options['timestamp']
              post_params['timestamp'] = (event.payload['timestamp'] || options['timestamp']).to_s
            end

            if event.payload['sound'] || options['sound']
              post_params['sound'] = (event.payload['sound'] || options['sound']).to_s
            end
            
            send_notification post_params
          end
        end
      end
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def send_notification(post_params)
      
    end

  end
end