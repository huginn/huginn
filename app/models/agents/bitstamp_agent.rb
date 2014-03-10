require 'bitstamp'

module Agents
  class BitstampAgent < Agent 
    cannot_receive_events!

    description <<-MD 
      The BitstampAgent creates an event to grab current values from Bitstamp.
    MD

    event_description <<-MD 
      Events look like this:

        {
          "date": "1357959600",
          "ticker": {
            "last": 100.00,
            "high": 100.00,
            "low": 100.00,
            "volume": 10000,
            "ask": 101.00,
            "bid": 99.00
          }
        }
    MD

    default_schedule "every_2m"

    def working?
      event_created_within?(2) && !recent_error_logs?
    end

    def default_options
      { }
    end

    def timestamp
      {
       "date" => Time.now.getutc.to_i
      }
    end

    def bitstamp
      {
        "ticker" => {
          'last'    => Bitstamp::Ticker.last,
          'high'    => Bitstamp::Ticker.high,
          'low'     => Bitstamp::Ticker.low,
          'volume'  => Bitstamp::Ticker.volume,
          'ask'     => Bitstamp::Ticker.ask,
          'bid'     => Bitstamp::Ticker.bid
        }
      }
    end

    def check
      create_event :payload => timestamp.merge(bitstamp)
    end
  end
end
