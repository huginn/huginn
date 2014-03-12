require 'bitstamp'

module Agents
  class BitstampAgent < Agent 
    cannot_receive_events!

    description <<-MD 
      The BitstampAgent creates an event to grab current values from Bitstamp.
    MD

    event_description <<-MD 
      {
        "high"=>"656.95", 
        "last"=>"642.10", 
        "timestamp"=>"1394647824", 
        "bid"=>"642.10", 
        "volume"=>"14498.76617782", 
        "low"=>"619.49", 
        "ask"=>"643.98"
      } 
    MD

    default_schedule "every_5m"

    def default_options
      { }
    end
    
    def working?
      event_created_within?(2) && !recent_error_logs?
    end

    def check
      create_event payload: ticker
    end

    def ticker
      result = { }

      Bitstamp.ticker.attributes.each do |k,v|
        result[k.to_s.delete('@')] = v
      end

      result
    end
  end
end
