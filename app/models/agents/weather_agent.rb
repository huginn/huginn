require 'date'
require 'cgi'

module Agents
  class WeatherAgent < Agent
    cannot_receive_events!

    gem_dependency_check { defined?(Wunderground) && defined?(ForecastIO) }

    description <<-MD
      The Weather Agent creates an event for the day's weather at a given `location`.

      #{'## Include `forecast_io` and `wunderground` in your Gemfile to use this Agent!' if dependencies_missing?}

      You also must select `which_day` you would like to get the weather for where the number 0 is for today and 1 is for tomorrow and so on. Weather is only returned for 1 week at a time.

      The weather can be provided by either Wunderground or ForecastIO. To choose which `service` to use, enter either `forecastio` or `wunderground`.

      The `location` can be a US zipcode, or any location that Wunderground supports. To find one, search [wunderground.com](http://wunderground.com) and copy the location part of the URL.  For example, a result for San Francisco gives `http://www.wunderground.com/US/CA/San_Francisco.html` and London, England gives `http://www.wunderground.com/q/zmw:00000.1.03772`.  The locations in each are `US/CA/San_Francisco` and `zmw:00000.1.03772`, respectively.

      If you plan on using ForecastIO, the `location` must be a comma-separated string of co-ordinates (longitude, latitude). For example, San Francisco would be `37.7771,-122.4196`.

      You must setup an [API key for Wunderground](http://www.wunderground.com/weather/api/) in order to use this Agent with Wunderground.

      You must setup an [API key for Forecast](https://developer.forecast.io/) in order to use this Agent with ForecastIO.

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
            "icon_url": "http://icons-ak.wxug.com/i/c/k/rain.gif",
            "skyicon": "mostlycloudy",
            ...
          }
    MD

    default_schedule "8pm"

    def working?
      event_created_within?((interpolated['expected_update_period_in_days'].presence || 2).to_i) && !recent_error_logs?
    end

    def key_setup?
      interpolated['api_key'].present? && interpolated['api_key'] != "your-key"
    end

    def default_options
      {
        'service' => 'wunderground',
        'api_key' => 'your-key',
        'location' => '94103',
        'which_day' => '1',
        'expected_update_period_in_days' => '2'
      }
    end
    
    def check
      if key_setup?
        create_event :payload => model(weather_provider, which_day).merge('location' => location)
      end
    end

    private
    
    def weather_provider
      interpolated["service"].presence || "wunderground"
    end

    def which_day
      (interpolated["which_day"].presence || 1).to_i
    end

    def location
      interpolated["location"].presence || interpolated["zipcode"]
    end

    def validate_options
      errors.add(:base, "service must be set to 'forecastio' or 'wunderground'") unless ["forecastio", "wunderground"].include?(weather_provider)
      errors.add(:base, "location is required") unless location.present?
      errors.add(:base, "api_key is required") unless key_setup?
      errors.add(:base, "which_day selection is required") unless which_day.present?
    end

    def wunderground
      Wunderground.new(interpolated['api_key']).forecast_for(location)['forecast']['simpleforecast']['forecastday'] if key_setup?
    end

    def forecastio
      if key_setup?
        ForecastIO.api_key = interpolated['api_key']
        lat, lng = location.split(',')
        ForecastIO.forecast(lat,lng)['daily']['data']
      end
    end

    def model(weather_provider,which_day)
      if weather_provider == "wunderground"
        wunderground[which_day]
      elsif weather_provider == "forecastio"
        forecastio.each do |value|
          timestamp = Time.at(value.time)
          if (timestamp.to_date - Time.now.to_date).to_i == which_day
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
  end
end
