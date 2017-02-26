module Agents
  class PushsaferAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!


    API_URL = 'https://www.pushsafer.com/api'

    description <<-MD
      The Pushsafer Agent receives and collects events and sends them via push notification to a device/device group.

      **You need a Pushsafer Private Key:** [https://www.pushsafer.com](https://www.pushsafer.com)

      * `k`: your private key
      * `expected_receive_period_in_days`:  is maximum number of days that you would expect to pass between events being received by this agent.

      The following options are all Liquid templates whose evaluated values will be posted to the Pushsafer API.  Only the `message` parameter is required, and if it is blank API call is omitted.

      Pushsafer API has a `4096` Character Limit including `title`.  `message` will be truncated.

      * `m` - your message (required)
      * `d` - your device or device group id to send the message directly to that device, rather than all of the devices
      * `t` - your notification's title
      * `u` - a supplementary URL or URL scheme to show with your message - `512` Character Limit
      * `ut` - a title for your supplementary URL, otherwise just the URL is shown - `512` Character Limit
      * `s` - the id of one of the sounds supported by device clients to override the user's default sound choice. [See Pushsafer API description for sound options.](https://www.pushsafer.com/en/pushapi)
      * `i` - the id of one of the icons. [See Pushsafer API description for sound options.](https://www.pushsafer.com/en/pushapi)
      * `v` - how often the device should vibrate (0-3).
      * `l` - Integer number 0-43200: Time in minutes, after which message automatically gets purged.

    MD

    def default_options
      {
        'k' => '',
        'm' => '{{ m }}',
        'd' => '{{ d }}',
        't' => '{{ t }}',
        'u' => '{{ u }}',
        'ut' => '{{ ut }}',
        's' => '{{ s }}',
	'i' => '{{ i }}',
	'v' => '{{ v }}',
	'l' => '{{ l }}',
        'expected_receive_period_in_days' => '1'
      }
    end

    def validate_options
      unless options['k'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, 'k=privatekey and expected_receive_period_in_days are all required.')
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          post_params = {}

          # required parameters
          %w[
            k
            m
          ].all? { |key|
            if value = String.try_convert(interpolated[key].presence)
              post_params[key] = value
            end
          } or next

          # optional parameters
          %w[
            d
            t
            u
            ut
            s
            i
            v
            l
          ].each do |key|
            if value = String.try_convert(interpolated[key].presence)
              case key
              when 'u'
                value.slice!(512..-1)
              when 'ut'
                value.slice!(512..-1)
              end
              post_params[key] = value
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
    end
  end
end
