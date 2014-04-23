require 'twilio-ruby'
require 'securerandom'

module Agents
  class TwilioAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      The TwilioAgent receives and collects events and sends them via text message or gives you a call when scheduled.

      It is assumed that events have a `message`, `text`, or `sms` key, the value of which is sent as the content of the text message/call. You can use Event Formatting Agent if your event does not provide these keys.

      Set `receiver_cell` to the number to receive text messages/call and `sender_cell` to the number sending them.

      `expected_receive_period_in_days` is maximum number of days that you would expect to pass between events being received by this agent.

      If you would like to receive calls, then set `receive_call` to true. `server_url` needs to be 
      filled only if you are making calls. Dont forget to include http/https in `server_url`.

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
      @client = Twilio::REST::Client.new options['account_sid'], options['auth_token']
      memory['pending_calls'] ||= {}
      incoming_events.each do |event|
        message = (event.payload['message'] || event.payload['text'] || event.payload['sms']).to_s
        if message != ""
          if options['receive_call'].to_s == 'true'
            secret = SecureRandom.hex 3
            memory['pending_calls'][secret] = message
            make_call secret
          end
          if options['receive_text'].to_s == 'true'
            message = message.slice 0..160
            send_message message
          end
        end
      end
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def send_message(message)
      @client.account.sms.messages.create :from => options['sender_cell'],
                                          :to => options['receiver_cell'],
                                          :body => message
    end

    def make_call(secret)
      @client.account.calls.create :from => options['sender_cell'],
                                   :to => options['receiver_cell'],
                                   :url => post_url(options['server_url'],secret)
    end

    def post_url(server_url,secret)
      "#{server_url}/users/#{self.user.id}/web_requests/#{self.id}/#{secret}"
    end

    def receive_web_request(params, method, format)
      if memory['pending_calls'].has_key? params['secret']
        response = Twilio::TwiML::Response.new {|r| r.Say memory['pending_calls'][params['secret']], :voice => 'woman'}
        memory['pending_calls'].delete params['secret']
        [response.text, 200]
      end
    end
  end
end