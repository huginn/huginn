
require 'net/http'

module Agents
  class Elks46MmsAgent < Agent
    no_bulk_receive!
    cannot_create_events!
    cannot_be_scheduled!
    description <<-MD
      Integration that enables you to **send** MMS from Huginn.

      Define your API credentials (`api_username` and `api_password`) which you can find at your [46elks account](https://46elks.com).

      Options:

      * `from` - The phone number to send from. Must be an MMS-enabled [Virtual Phone Number](https://46elks.com/products/virtual-numbers) or the text "noreply". We will replace the sender id with a random phone number if "noreply" is used.

      * `to` - The phone number of the recipient in [E.164 format](https://46elks.com/kb/e164).

      * `message` - A message to be sent with the MMS. Either message or image must be present in the API request.

      * `image` - Either a data URL or a publicly accessible URL that points to an image. GIF, PNG and JPEG images are supported. Either image or message must be present in the API request.
    MD

    def default_options
      {
          'api_username' => 'u6xxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          'api_password' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          'from' => 'noreply',
          'to' => ['+46700000000'],
          'image' => 'https://46elks.com/press/46elks-blue-png',
          'message' => 'Hello this is Huginn using 46elks.',
      }
    end

    def validate_options
      unless options['api_username'].present?
        errors.add(:base, '`api_username` is required.')
      end
      unless options['api_password'].present?
        errors.add(:base, '`api_password` is required.')
      end
      unless interpolated['from'].present?
        errors.add(:base, '`from` is required.')
      end
      unless interpolated['to'].present?
        errors.add(:base, '`to` is required.')
      end
      unless interpolated['message'].present? || interpolated['image'].present?
        errors.add(:base, 'At least one of `image` or `message` must be present.')
      end
    end

    def working?
      !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with event do
          send_mms(interpolated)
        end
      end
    end

    def send_mms(payload)
      payload['to'].each do |to_recipient|
        uri = URI('https://api.46elks.com/a1/mms')
        req = Net::HTTP::Post.new(uri)
        req.basic_auth options['api_username'], options['api_password']
        req.set_form_data(
          :from => payload['from'],
          :to => to_recipient,
          :image => payload['image'],
          :message => payload['message']
        )

        res = Net::HTTP.start(
            uri.host,
            uri.port,
            :use_ssl => uri.scheme == 'https') do |http|
          http.request req
        end

        unless res.is_a?(Net::HTTPSuccess)
          error("Error: #{res.body}")
        end
      end
    end
  end
end