module Agents
  class BoxcarAgent < Agent

    cannot_be_scheduled!
    cannot_create_events!

    API_URL = 'https://new.boxcar.io/api/notifications'

    description <<-MD
      The Boxcar agent sends push notifications to iPhone.

      To be able to use the Boxcar end-user API, you need your `Access Token`.
      The access token is available on general "Settings" screen of Boxcar iOS
      app or from Boxcar Web Inbox settings page.

      Please provide the access token as `user_credentails` in `options` or create a
      `boxcar_api_key` credential. The value in `user_credentials` will be considered if
      specified in both places.

      Options:

      * `user_credentials` - Boxcar access token.
      * `title` - Title of the message.
      * `body` - Body of the message.
      * `source_name` - Name of the source of the message. Set to `Huginn` by default.
      * `icon_url` - URL to the icon.
      * `sound` - Sound to be played for the notification. Set to 'bird-1' by default.
    MD

    def default_options
      {
        'user_credentials' => '',
        'title' => "{{title}}",
        'body' => "{{body}}",
        'source_name' => "Huginn",
        'icon_url' => "",
        'sound' => "bird-1"
      }
    end

    def working?
      received_event_without_error?
    end

    def strip(string)
      puts string
      string.strip! || string
    end

    def validate_options
      errors.add(:base, "you need to specify a boxcar api key") if options['user_credentials'].blank?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload_interpolated = interpolated(event)
        user_credentials = payload_interpolated['user_credentials'] || credential('boxcar_api_key')
        post_params = {
          'user_credentials' => user_credentials,
          'notification' => {
            'title' => strip(payload_interpolated['title']),
            'long_message' => strip(payload_interpolated['body']),
            'source_name' => payload_interpolated['source_name'],
            'sound' => payload_interpolated['sound'],
            'icon_url' => payload_interpolated['icon_url']
          }
        }
        send_notification(post_params)
      end
    end

    def send_notification(post_params)
      response = HTTParty.post(API_URL, :query => post_params)
      raise StandardError, response['error']['message'] if response['error'].present?
      if response['Response'].present?  and response['Response'] == "Not authorized"
        raise StandardError, response['Response']
      end
    end
  end
end
