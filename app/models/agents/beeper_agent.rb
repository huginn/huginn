module Agents
  class BeeperAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    description <<-MD
      Beeper agent sends messages to Beeper app on your mobile device via Push notifications.

      You need a Beeper Application ID (`app_id`), Beeper REST API Key (`api_key`) and Beeper Sender ID (`sender_id`) [https://beeper.io](https://beeper.io)

      You have to provide phone number (`phone`) of the recipient which have a mobile device with Beeper installed, or a `group_id` – Beeper Group ID

      Also you have to provide a message `type` which has to be `message`, `image`, `event`, `location` or `task`.

      Depending on message type you have to provide additional fields:

      ##### Message
      * `text` – **required**

      ##### Image
      * `image` – **required** (Image URL or Base64-encoded image)
      * `text` – optional

      ##### Event
      * `text` – **required**
      * `start_time` – **required** (Corresponding to ISO 8601)
      * `end_time` – optional (Corresponding to ISO 8601)

      ##### Location
      * `latitude` – **required**
      * `longitude` – **required**
      * `text` – optional

      ##### Task
      * `text` – **required**

      You can see additional documentation at [Beeper website](https://beeper.io/docs)
    MD

    BASE_URL = 'https://api.beeper.io/api'

    TYPE_ATTRIBUTES = {
      'message'  => %w(text),
      'image'    => %w(text image),
      'event'    => %w(text start_time end_time),
      'location' => %w(text latitude longitude),
      'task'     => %w(text)
    }

    MESSAGE_TYPES = TYPE_ATTRIBUTES.keys

    TYPE_REQUIRED_ATTRIBUTES = {
      'message'  => %w(text),
      'image'    => %w(image),
      'event'    => %w(text start_time),
      'location' => %w(latitude longitude),
      'task'     => %w(text)
    }

    def default_options
      {
        'type'      => 'message',
        'app_id'    => '',
        'api_key'   => '',
        'sender_id' => '',
        'phone'     => '',
        'text'      => '{{title}}'
      }
    end

    def validate_options
      %w(app_id api_key sender_id type).each do |attr|
        errors.add(:base, "you need to specify a #{attr}") if options[attr].blank?
      end

      if options['type'].in?(MESSAGE_TYPES)
        required_attributes = TYPE_REQUIRED_ATTRIBUTES[options['type']]
        if required_attributes.any? { |attr| options[attr].blank? }
          errors.add(:base, "you need to specify a #{required_attributes.join(', ')}")
        end
      else
        errors.add(:base, 'you need to specify a valid message type')
      end

      unless options['group_id'].blank? ^ options['phone'].blank?
        errors.add(:base, 'you need to specify a phone or group_id')
      end
    end

    def working?
      received_event_without_error? && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        send_message(event)
      end
    end

    def send_message(event)
      mo = interpolated(event)
      begin
        response = HTTParty.post(endpoint_for(mo['type']), body: payload_for(mo), headers: headers)
        error(response.body) if response.code != 201
      rescue HTTParty::Error => e
        error(e.message)
      end
    end

    private

    def headers
      {
        'X-Beeper-Application-Id' => options['app_id'],
        'X-Beeper-REST-API-Key'   => options['api_key'],
        'Content-Type' => 'application/json'
      }
    end

    def payload_for(mo)
      mo.slice(*TYPE_ATTRIBUTES[mo['type']], 'sender_id', 'phone', 'group_id').to_json
    end

    def endpoint_for(type)
      "#{BASE_URL}/#{type}s.json"
    end
  end
end