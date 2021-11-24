module Agents
  class PushoverAgent < Agent
    can_dry_run!
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!


    API_URL = 'https://api.pushover.net/1/messages.json'

    description <<-MD
      The Pushover Agent receives and collects events and sends them via push notification to a user/group.

      **You need a Pushover API Token:** [https://pushover.net/apps/build](https://pushover.net/apps/build)

      * `token`: your application's API token
      * `user`: the user or group key (not e-mail address).
      * `expected_receive_period_in_days`:  is maximum number of days that you would expect to pass between events being received by this agent.

      The following options are all [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) templates whose evaluated values will be posted to the Pushover API.  Only the `message` parameter is required, and if it is blank API call is omitted.

      Pushover API has a `512` Character Limit including `title`.  `message` will be truncated.

      * `message` - your message (required)
      * `device` - your user's device name to send the message directly to that device, rather than all of the user's devices
      * `title` or `subject` - your notification's title
      * `url` - a supplementary URL to show with your message - `512` Character Limit
      * `url_title` - a title for your supplementary URL, otherwise just the URL is shown - `100` Character Limit
      * `timestamp` - a [Unix timestamp](https://en.wikipedia.org/wiki/Unix_time) of your message's date and time to display to the user, rather than the time your message is received by the Pushover API.
      * `priority` - send as `-1` to always send as a quiet notification, `0` is default, `1` to display as high-priority and bypass the user's quiet hours, or `2` for emergency priority: [Please read Pushover Docs on Emergency Priority](https://pushover.net/api#priority)
      * `sound` - the name of one of the sounds supported by device clients to override the user's default sound choice. [See PushOver docs for sound options.](https://pushover.net/api#sounds)
      * `retry` - Required for emergency priority - Specifies how often (in seconds) the Pushover servers will send the same notification to the user. Minimum value: `30`
      * `expire` - Required for emergency priority - Specifies how many seconds your notification will continue to be retried for (every retry seconds). Maximum value: `86400`
      * `html` - set to `true` to have Pushover's apps display the `message` content as HTML

    MD

    def default_options
      {
        'token' => '',
        'user' => '',
        'message' => '{{ message }}',
        'device' => '{{ device }}',
        'title' => '{{ title }}',
        'url' => '{{ url }}',
        'url_title' => '{{ url_title }}',
        'priority' => '{{ priority }}',
        'timestamp' => '{{ timestamp }}',
        'sound' => '{{ sound }}',
        'retry' => '{{ retry }}',
        'expire' => '{{ expire }}',
        'html' => 'false',
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
        interpolate_with(event) do
          post_params = {}

          # required parameters
          %w[
            token
            user
            message
          ].all? { |key|
            if value = String.try_convert(interpolated[key].presence)
              post_params[key] = value
            end
          } or next

          # optional parameters
          %w[
            device
            title
            url
            url_title
            priority
            timestamp
            sound
            retry
            expire
          ].each do |key|
            if value = String.try_convert(interpolated[key].presence)
              case key
              when 'url'
                value.slice!(512..-1)
              when 'url_title'
                value.slice!(100..-1)
              end
              post_params[key] = value
            end
          end
          # html is special because String.try_convert(true) gives nil (not even "nil", just nil)
          if value = interpolated['html'].presence
            post_params['html'] =
              case value.to_s
              when 'true', '1'
                '1'
              else
                '0'
              end
          end

          send_notification(post_params)
        end
      end
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def send_notification(post_params)
      response = HTTParty.post(API_URL, query: post_params)
      puts response
      log "Sent the following notification: \"#{post_params.except('token').inspect}\""
    end
  end
end
