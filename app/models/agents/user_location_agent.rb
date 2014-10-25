require 'securerandom'

module Agents
  class UserLocationAgent < Agent
    cannot_be_scheduled!

    description do
      <<-MD
        The UserLocationAgent creates events based on WebHook POSTS that contain a `latitude` and `longitude`.  You can use the [POSTLocation](https://github.com/cantino/post_location) or [PostGPS](https://github.com/chriseidhof/PostGPS) iOS app to post your location.


        Your POST path will be `https://#{ENV['DOMAIN']}/users/#{user.id}/update_location/:secret` where `:secret` is specified in your options.
      MD
    end

    event_description <<-MD
      Assuming you're using the iOS application, events look like this:

          {
            "latitude": "37.12345",
            "longitude": "-122.12345",
            "timestamp": "123456789.0",
            "altitude": "22.0",
            "horizontal_accuracy": "5.0",
            "vertical_accuracy": "3.0",
            "speed": "0.52595",
            "course": "72.0703",
            "device_token": "..."
          }
    MD

    def working?
      event_created_within?(2) && !recent_error_logs?
    end

    def default_options
      { 'secret' => SecureRandom.hex(7) }
    end

    def validate_options
      errors.add(:base, "secret is required and must be longer than 4 characters") unless options['secret'].present? && options['secret'].length > 4
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          handle_payload event.payload
        end
      end
    end

    def receive_web_request(params, method, format)
      params = params.symbolize_keys
      if method != 'post'
        return ['Not Found', 404]
      end
      if interpolated['secret'] != params[:secret]
        return ['Not Authorized', 401]
      end

      handle_payload params.except(:secret)

      return ['ok', 200]
    end

    private

    def handle_payload(payload)
      location = Location.new(payload)

      if location.present?
        create_event payload: payload, location: location
      end
    end
  end
end
