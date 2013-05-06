require 'rubygems'
require 'twilio-ruby'  

module Agents
    class TwilioAgent < Agent

        default_schedule "every_10m"

        description <<-MD
            The TwilioAgent receives and collects events and send them via text message to cellphone when scheduled.It is assumed that events have `:message`,`:text` or `:sms` key, the value of which is sent as the content of the text message.
            Set `receiver_cell` to the number on which you would like to receive text messages.
            `expected_receive_period_in_days` is maximum days that you would expect to pass between events being received by this agent. 
        MD

        def default_options
            {
                :account_sid   => "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
                :auth_token    => "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
                :sender_cell   => "xxxxxxxxxx",
                :receiver_cell => "xxxxxxxxxx",
                :expected_receive_period_in_days => "x"
            }
        end

        def validate_options
            errors.add(:base, "account_sid,auth_token,sender_cell,receiver_cell,expected_receive_period_in_days are all required") unless options[:account_sid].present? && options[:auth_token].present? && options[:sender_cell].present? && options[:receiver_cell].present? && options[:expected_receive_period_in_days].present?
        end

        def receive(incoming_events)
            incoming_events.each do |event|
                self.memory[:queue] ||= [] # If memory[:queue] is not true, assign [] to it, a || a = b
                self.memory[:queue] << event.payload # Append
            end
        end

        def working?
            last_receive_at && last_receive_at > options[:expected_receive_period_in_days].to_i.days.ago
        end

        def send_message(client,message)
            client.account.sms.messages.create(:from=>options[:sender_cell],:to=>options[:receiver_cell],:body=>message)
        end

        def check
            if self.memory[:queue] && self.memory[:queue].length > 0
                @client = Twilio::REST::Client.new options[:account_sid],options[:auth_token]
                self.memory[:queue].each do |text|
                    message = text[:message] || text[:text] || text[:sms]
                    if message
                        message.slice! 160, message.length
                        send_message @client, message
                    end
                end
                self.memory[:queue] = []
            end
        end
    end
end