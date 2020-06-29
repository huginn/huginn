require 'net/http'

module Agents
  class Elks46SmsAgent < Agent
    no_bulk_receive!
    cannot_create_events!
    cannot_be_scheduled!
    description <<-MD
      Integration that enables you to **send** SMS from Huginn.

      Define your API credentials (`api_username` and `api_password`) which you can find at your [46elks account](https://46elks.com).

      Options:

      * `from` - Either a [text sender ID](https://46elks.com/kb/text-sender-id) or a [virtual phone number](https://46elks.com/products/virtual-numbers) in [E.164 format](https://46elks.com/kb/e164) if you want to be able to receive replies.

      * `to` - The phone number of the recipient in [E.164 format](https://46elks.com/kb/e164).

      * `message` - The message you want to send.
    MD

    # There is a form_configurable for extra options, this can be used instead of the default options.
    # It's located in app/concerns/form_configurable.rb
    def default_options
      {
        'api_username' => 'u6xxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'api_password' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'from' => 'Huginn',
        'to' => ['+46700000000'],
        'message' => 'Hello this message from your friend Huginn.',
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
      unless interpolated['message'].present?
        errors.add(:base, '`message` is required.')
      end
    end

    def working?
      !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
          interpolate_with event do
            send_sms(interpolated)
          end
      end
    end

    def send_sms(payload)
      payload['to'].each do |to_recipient|
        uri = URI('https://api.46elks.com/a1/sms')
        req = Net::HTTP::Post.new(uri)
        req.basic_auth payload['api_username'], payload['api_password']
        req.set_form_data(
          :from => payload['from'],
          :to => to_recipient,
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
