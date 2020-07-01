
require 'net/http'

module Agents
  class Elks46PhoneCallAgent < Agent
    no_bulk_receive!
    cannot_create_events!
    cannot_be_scheduled!
    description <<-MD
      Integration that enables you to make phone calls from Huginn.

      Define your API credentials (`api_username` and `api_password`) which you can find at your [46elks account](https://46elks.com).

      Options:

      * `from` - A valid phone number in [E.164 format](https://46elks.com/kb/e164). Can be one of your voice enabled 46elks numbers, the phone number you signed up with, or an unlocked number.
      
      * `to` - The phone number of the recipient in [E.164 format](https://46elks.com/kb/e164).

      * `voice_start` - A webhook URL that returns the first action to execute. See [Call actions](https://46elks.com/docs/call-actions) for details. It is also possible to add a JSON struct for direct call actions without any logic, like: {"connect":"+46766861004"}.   
      MD

    # There is a form_configurable for extra options, this can be used instead of the default options.
    # It's located in app/concerns/form_configurable.rb


    def default_options
      {
          'api_username' => 'u6xxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          'api_password' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
          'from' => '+xxxxxxxxxxx',
          'to' => ['+46700000000'],
          'voice_start' => '{"play":"https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_700KB.mp3"}',
      }
    end

    def validate_options
      # Should validate even more, especially the api keys
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
      unless interpolated['voice_start'].present?
        errors.add(:base, '`voice_start` is required.')
      end
      unless /{"(play|record|recordcall|ivr|hangup)":".*"}/.match(interpolated['voice_start'])
        errors.add(:base, '`voice_start` needs to include a valid call action and value. See https://46elks.com/docs/call-actions for more information.')
      end
    end

    def working?
      !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with event do
          make_phone_call(interpolated)
        end
      end
    end

    def make_phone_call(payload)
      payload['to'].each do |to_recipient|
        uri = URI('https://api.46elks.com/a1/calls')
        req = Net::HTTP::Post.new(uri)
        req.basic_auth options['api_username'], options['api_password']
        req.set_form_data(
          :from => payload['from'],
          :to => to_recipient,
          :voice_start => payload['voice_start']
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