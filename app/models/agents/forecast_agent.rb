require 'forecast_io'
require 'date'

module Agents
  class ForecastAgent < Agent
    cannot_receive_events!

    description <<-MD
      The ForecastAgent creates an event for the following day's weather at a given `latitude` and `longitude`.

      You also must select which `day` you would like to get the weather for where the number 0 is for today and 1 is for tomorrow and so on. Weather is only returned for 1 week at a time.

      You must setup an [API key for Forecast](https://developer.forecast.io/) in order to use this Agent.
    MD

    event_description <<-MD
      Events look like this:

          {
            "time" : 1391320800,
            "summary" : "Rain throughout the day.",
            "icon" : "rain",
            "sunriseTime" : "06:48",
            "sunsetTime" : "17:16",
            "moonPhase" : 0.11,
            "precipIntensity" : 0.0582,
            "precipIntensityMax" : 0.1705,
            "precipIntensityMaxTime" : "21:00",
            "precipProbability" : 1,
            "precipType" : "rain",
            "temperatureMin" : 35.67,
            "temperatureMinTime" : "23:00",
            "temperatureMax" : 50.82,
            "temperatureMaxTime" : "02:00",
            "apparentTemperatureMin" : 26.11,
            "apparentTemperatureMinTime" : "23:00",
            "apparentTemperatureMax" : 50.82,
            "apparentTemperatureMaxTime" : "02:00",
            "dewPoint" : 41,
            "humidity" : 0.92,
            "windSpeed" : 4.59,
            "windBearing" : 358,
            "visibility" : 5.92,
            "cloudCover" : 0.99,
            "pressure" : 1017.66,
            "ozone" : 278.6
          }

    MD

    default_schedule "8pm"

    def working?
      event_created_within?(2) && !recent_error_logs?
    end

    def key_setup?
      options['api_key'] && options['api_key'] != "your-key"
    end

    def default_options
      {
        'api_key' => "your-key",
        'latitude' => "36.166667",
        'longitude' => "-86.783333",
        'day' => "0"
      }
    end

    def validate_options
      errors.add(:base, "latitude is required") unless options['latitude'].present?
      errors.add(:base, "longitude is required") unless options['longitude'].present?
      errors.add(:base, "api_key is required") unless options['api_key'].present?
      errors.add(:base, "day selection is required") unless options['day'].present?
    end

    def check
      if key_setup?
        ForecastIO.api_key = options['api_key']
        ForecastIO.forecast(options['latitude'],options['longitude']).daily.each do |key, value|
          if key == "data"
            value.each do |day|
              if day_diff(day.time) == options['day'].tp_i
                day.sunriseTime = Time.at(day.sunriseTime).strftime("%H:%M")
                day.sunsetTime = Time.at(day.sunsetTime).strftime("%H:%M")
                day.precipIntensityMaxTime = Time.at(day.precipIntensityMaxTime).strftime("%H:%M")
                day.temperatureMinTime = Time.at(day.temperatureMinTime).strftime("%H:%M")
                day.temperatureMaxTime = Time.at(day.temperatureMaxTime).strftime("%H:%M")
                day.apparentTemperatureMinTime = Time.at(day.apparentTemperatureMinTime).strftime("%H:%M")
                day.apparentTemperatureMaxTime = Time.at(day.apparentTemperatureMaxTime).strftime("%H:%M")
                create_event :payload => day
              end
            end
          end
        end
      end
    end

    def day_diff(day)
      a=Time.at(day).to_date
      b=Time.now.to_date
      days=(a-b).to_i
      return  days
    end

  end
end
