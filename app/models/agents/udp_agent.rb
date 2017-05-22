require 'socket'

module Agents
  class UdpAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
       Udp Agent receives events from other agents and send those events as the contents of a UDP packet to a specified host/port couple. `host` field must specify the host that listen for UDP connection and `port` field must specify the port used for the connection
    MD

    event_description "Does not produce events."

    def default_options
      {
        :host => "0.0.0.0",
        :port => "1701",
        :expected_receive_period_in_days => 1
      }
    end

    def working?
      last_receive_at && last_receive_at > options[:expected_receive_period_in_days].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      unless options[:host].present? && options[:port].present? && options[:expected_receive_period_in_days].present?
        errors.add(:base, "host, port and expected_receive_period_in_days are required fields")
      end
    end

    def udp_event(host,port,event)
      socket = UDPSocket.new
      socket.send(event.to_s, 0, host, port)
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        udp_event options[:host], options[:port], event.payload
      end
    end
  end
end
