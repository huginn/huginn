require 'date'
require 'cgi'

module Agents
  class WeatherAgent < Agent
    cannot_receive_events!

    description <<-MD
      The WeatherAgent creates an event for the following day's weather at a given `location`.

      The `location` can be a US zipcode, or any location that Wunderground supports.  To find one, search [wunderground.com](http://wunderground.com) and copy the location part of the URL.  For example, a result for San Francisco gives `http://www.wunderground.com/US/CA/San_Francisco.html` and London, England gives `http://www.wunderground.com/q/zmw:00000.1.03772`.  The locations in each are `US/CA/San_Francisco` and `zmw:00000.1.03772`, respectively.

      You must setup an [API key for Wunderground](http://www.wunderground.com/weather/api/) in order to use this Agent.
    MD

    event_description <<-MD
      Events look like this:

          {
            "location": 12345,
            "date": {
              "epoch": "1357959600",
              "pretty": "10:00 PM EST on January 11, 2013"
            },
            "high": {
              "fahrenheit": "64",
              "celsius": "18"
            },
            "low": {
              "fahrenheit": "52",
              "celsius": "11"
            },
            "conditions": "Rain Showers",
            "icon": "rain",
            "icon_url": "http://icons-ak.wxug.com/i/c/k/rain.gif",
            "skyicon": "mostlycloudy",
            ...
          }
    MD

    default_schedule "8pm"

    def working?
      event_created_within?(2) && !recent_error_logs?
    end

    def wunderground
      Wunderground.new(options['api_key']) if key_setup?
    end

    def key_setup?
      options['api_key'] && options['api_key'] != "your-key"
    end

    def default_options
      {
        'api_key' => "your-key",
        'location' => "94103"
      }
    end

    def validate_options
      errors.add(:base, "location is required") unless options['location'].present? || options['zipcode'].present?
      errors.add(:base, "api_key is required") unless options['api_key'].present?
    end

    def check
      if key_setup?
        wunderground.forecast_for(options['location'] || options['zipcode'])["forecast"]["simpleforecast"]["forecastday"].each do |day|
          if is_tomorrow?(day)
            create_event :payload => day.merge('location' => options['location'] || options['zipcode'])
          end
        end
      end
    end

    def is_tomorrow?(day)
      Time.zone.at(day["date"]["epoch"].to_i).to_date == Time.zone.now.tomorrow.to_date
    end
  end
end
