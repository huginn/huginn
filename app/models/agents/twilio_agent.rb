require 'securerandom'

module Agents
  class TwilioAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!
    no_bulk_receive!

    gem_dependency_check { defined?(Twilio) }

    description <<-MD
      The Twilio Agent receives and collects events and sends them via text message (up to 160 characters) or gives you a call when scheduled.

      #{'## Include `twilio-ruby` in your Gemfile to use this Agent!' if dependencies_missing?}

      It is assumed that events have a `message`, `text`, or `sms` key, the value of which is sent as the content of the text message/call. You can use the EventFormattingAgent if your event does not provide these keys.

      Set `receiver_cell` to the number to receive text messages/call and `sender_cell` to the number sending them.

      `expected_receive_period_in_days` is maximum number of days that you would expect to pass between events being received by this agent.

      If you would like to receive calls, set `receive_call` to `true`. In this case, `server_url` must be set to the URL of your
      Huginn installation (probably "https://#{ENV['DOMAIN']}"), which must be web-accessible.  Be sure to set http/https correctly.
    MD

    def default_options
      {
        'account_sid' => 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'auth_token' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'sender_cell' => 'xxxxxxxxxx',
        'receiver_cell' => 'xxxxxxxxxx',
        'server_url'    => 'http://somename.com:3000',
        'receive_text'  => 'true',
        'receive_call'  => 'false',
        'expected_receive_period_in_days' => '1'
      }
    end

    def validate_options
      unless options['account_sid'].present? && options['auth_token'].present? && options['sender_cell'].present? && options['receiver_cell'].present? && options['expected_receive_period_in_days'].present? && options['receive_call'].present? && options['receive_text'].present?
        errors.add(:base, 'account_sid, auth_token, sender_cell, receiver_cell, receive_text, receive_call and expected_receive_period_in_days are all required')
      end
    end

    def receive(incoming_events)
      memory['pending_calls'] ||= {}
      incoming_events.each do |event|
        message = (event.payload['message'].presence || event.payload['text'].presence || event.payload['sms'].presence).to_s
        if message.present?
          if boolify(interpolated(event)['receive_call'])
            secret = SecureRandom.hex 3
            memory['pending_calls'][secret] = message
            make_call secret
          end

          if boolify(interpolated(event)['receive_text'])
            message = message.slice 0..160
            send_message message
          end
        end
      end
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def send_message(message)
      client.account.messages.create :from => interpolated['sender_cell'],
                                         :to => interpolated['receiver_cell'],
                                         :body => message
    end

    def make_call(secret)
      client.account.calls.create :from => interpolated['sender_cell'],
                                  :to => interpolated['receiver_cell'],
                                  :url => post_url(interpolated['server_url'], secret)
    end

    def post_url(server_url, secret)
      "#{server_url}/users/#{user.id}/web_requests/#{id}/#{secret}"
    end

    def receive_web_request(params, method, format)
      if memory['pending_calls'].has_key? params['secret']
        response = Twilio::TwiML::Response.new {|r| r.Say memory['pending_calls'][params['secret']], :voice => 'woman'}
        memory['pending_calls'].delete params['secret']
        [response.text, 200]
      end
    end

    def client
      @client ||= Twilio::REST::Client.new interpolated['account_sid'], interpolated['auth_token']
    end
  end
end
