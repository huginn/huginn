require 'date'
require 'cgi'

module Agents
  class WeatherAgent < Agent
    cannot_receive_events!

    gem_dependency_check { defined?(ForecastIO) }

    description <<-MD
      The Weather Agent creates an event for the day's weather at a given `location`.

      #{'## Include `forecast_io` in your Gemfile to use this Agent!' if dependencies_missing?}

      You also must select when you would like to get the weather forecast for using the `which_day` option, where the number 1 represents today, 2 represents tomorrow and so on. Weather forecast inforation is only returned for at most one week at a time.

      The weather forecast information is provided by Dark Sky. 

      The `location` must be a comma-separated string of map co-ordinates (longitude, latitude). For example, San Francisco would be `37.7771,-122.4196`.

      You must set up an [API key for Dark Sky](https://darksky.net/dev/) in order to use this Agent.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

    MD

    event_description <<-MD
      Events look like this:

          {
            "location": "12345",
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
            "icon_url": "https://icons-ak.wxug.com/i/c/k/rain.gif",
            "skyicon": "mostlycloudy",
            ...
          }
    MD

    default_schedule "8pm"

    def working?
      event_created_within?((interpolated['expected_update_period_in_days'].presence || 2).to_i) && !recent_error_logs? && key_setup?
    end

    def key_setup?
      interpolated['api_key'].present? && interpolated['api_key'] != "your-key" && interpolated['api_key'] != "put-your-key-here"
    end

    def default_options
      {
        'api_key' => 'your-key',
        'location' => '37.779329,-122.41915',
        'which_day' => '1',
        'expected_update_period_in_days' => '2',
        'language' => 'en'
      }
    end

    def check
      if key_setup?
        create_event :payload => model(which_day).merge('location' => location)
      end
    end

    private

    def which_day
      (interpolated["which_day"].presence || 1).to_i
    end

    def location
      interpolated["location"].presence || interpolated["zipcode"]
    end

    def coordinates
      location.split(',').map { |e| e.to_f }
    end

    def language
      interpolated["language"].presence || "en"
    end

    def wunderground? 
      interpolated["service"].presence && interpolated["service"].presence.downcase == "wunderground"
    end

    VALID_COORDS_REGEX = /^\s*-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+\s*$/

    def validate_location
      errors.add(:base, "location is required") unless location.present?
      if location =~ VALID_COORDS_REGEX
        lat, lon = coordinates
        errors.add :base, "too low of a latitude" unless lat > -90
        errors.add :base, "too big of a latitude" unless lat < 90
        errors.add :base, "too low of a longitude" unless lon > -180
        errors.add :base, "too high of a longitude" unless lon < 180
      else
        errors.add(
          :base,
          "Location #{location} is malformed. Location for " +
          'Dark Sky must be in the format "-00.000,-00.00000". The ' +
          "number of decimal places does not matter.")
      end
    end

    def validate_options
      errors.add(:base, "The Weather Underground API has been disabled since Jan 1st 2018, please switch to DarkSky") if wunderground?
      validate_location
      errors.add(:base, "api_key is required") unless interpolated['api_key'].present?
      errors.add(:base, "which_day selection is required") unless which_day.present?
    end

    def dark_sky
      if key_setup?
        ForecastIO.api_key = interpolated['api_key']
        lat, lng = coordinates
        ForecastIO.forecast(lat, lng, params: {lang: language.downcase})['daily']['data']
      end
    end

    def model(which_day)
      value = dark_sky[which_day - 1]
      if value
        timestamp = Time.at(value.time)
        day = {
          'date' => {
            'epoch' => value.time.to_s,
            'pretty' => timestamp.strftime("%l:%M %p %Z on %B %d, %Y"),
            'day' => timestamp.day,
            'month' => timestamp.month,
            'year' => timestamp.year,
            'yday' => timestamp.yday,
            'hour' => timestamp.hour,
            'min' => timestamp.strftime("%M"),
            'sec' => timestamp.sec,
            'isdst' => timestamp.isdst ? 1 : 0 ,
            'monthname' => timestamp.strftime("%B"),
            'monthname_short' => timestamp.strftime("%b"),
            'weekday_short' => timestamp.strftime("%a"),
            'weekday' => timestamp.strftime("%A"),
            'ampm' => timestamp.strftime("%p"),
            'tz_short' => timestamp.zone
          },
          'period' => which_day.to_i,
          'high' => {
            'fahrenheit' => value.temperatureMax.round().to_s,
            'epoch' => value.temperatureMaxTime.to_s,
            'fahrenheit_apparent' => value.apparentTemperatureMax.round().to_s,
            'epoch_apparent' => value.apparentTemperatureMaxTime.to_s,
            'celsius' => ((5*(Float(value.temperatureMax) - 32))/9).round().to_s
          },
          'low' => {
            'fahrenheit' => value.temperatureMin.round().to_s,
            'epoch' => value.temperatureMinTime.to_s,
            'fahrenheit_apparent' => value.apparentTemperatureMin.round().to_s,
            'epoch_apparent' => value.apparentTemperatureMinTime.to_s,
            'celsius' => ((5*(Float(value.temperatureMin) - 32))/9).round().to_s
          },
          'conditions' => value.summary,
          'icon' => value.icon,
          'avehumidity' => (value.humidity * 100).to_i,
          'sunriseTime' => value.sunriseTime.to_s,
          'sunsetTime' => value.sunsetTime.to_s,
          'moonPhase' => value.moonPhase.to_s,
          'precip' => {
            'intensity' => value.precipIntensity.to_s,
            'intensity_max' => value.precipIntensityMax.to_s,
            'intensity_max_epoch' => value.precipIntensityMaxTime.to_s,
            'probability' => value.precipProbability.to_s,
            'type' => value.precipType
          },
          'dewPoint' => value.dewPoint.to_s,
          'avewind' => {
            'mph' => value.windSpeed.round().to_s,
            'kph' =>  (Float(value.windSpeed) * 1.609344).round().to_s,
            'degrees' => value.windBearing.to_s
          },
          'visibility' => value.visibility.to_s,
          'cloudCover' => value.cloudCover.to_s,
          'pressure' => value.pressure.to_s,
          'ozone' => value.ozone.to_s
        }
        return day
      end
    end
  end
end
