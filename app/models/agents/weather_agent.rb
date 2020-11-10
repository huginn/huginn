require 'date'
require 'cgi'

module Agents
  class WeatherAgent < Agent
    cannot_receive_events!

    gem_dependency_check { defined?(ForecastIO) }

    description <<-MD
      The Weather Agent creates an event for the day's weather at a given `location`.

      #{'## Include `forecast_io` in your Gemfile to use this Agent!' if dependencies_missing?}

      You can specify for which day you would like the weather forecast using the `which_day` option, where the number 1 represents today, 2 represents tomorrow, and so on. The default is 1 (today). If you schedule this to run at night, you probably want 2 (tomorrow). Weather forecast inforation is only returned for at most one week at a time.

      The `location` must be a comma-separated string of map co-ordinates (longitude, latitude). For example, San Francisco would be `37.7771,-122.4196`.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      The weather forecast information is provided by [OpenWeather](https://home.openweathermap.org) or Dark Sky - to choose which set `sevice` to either `openweather` or `forecastio` (Dark Sky). If `service` is not specified, it will default to `forecastio` to avoid breaking older configurations.

      You must set up an [API key for OpenWeather](https://home.openweathermap.org/api_keys) or have an existing [API key from Dark Sky](https://darksky.net/dev/) in order to use this Agent.

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
            "icon_url": "http://openweathermap.org/img/wn/10d@2x.png",
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
        'service' => 'openweather',
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

    def dark_sky?
      # Default to Dark Sky if the service is not defined, or set to the old forecastio value for backwards
      # compatibility with old configurations.
      interpolated["service"].nil? || interpolated["service"].downcase == "forecastio"
    end

    def wunderground?
      interpolated["service"].present? && interpolated["service"].downcase == "wunderground"
    end

    def openweather?
      interpolated["service"].present? && interpolated["service"].downcase == "openweather"
    end

    def which_day
      (interpolated["which_day"].presence || 1).to_i
    end

    def location
      interpolated["location"].presence
    end

    def coordinates
      location.split(',').map { |e| e.to_f }
    end

    def language
      interpolated["language"].presence || "en"
    end

    private

    def openweather_icon(code)
      "http://openweathermap.org/img/wn/#{code}@2x.png"
    end

    def figure_rain_or_snow(rain, snow)
      if rain.present? && (snow.nil? || (rain > snow))
        "rain"
      elsif snow.present?
        "snow"
      else
        ""
      end
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
          'OpenWeather must be in the format "-00.000,-00.00000". The ' +
          "number of decimal places does not matter.")
      end
    end

    def validate_options
      validate_location
      errors.add(:base, "api_key is required") unless interpolated['api_key'].present?
      errors.add(:base, "which_day selection is required") unless which_day.present?
      errors.add(:base, "service must be one of: forecastio, openweather") unless
        interpolated['service'].nil? or ['forecastio', 'openweather'].include? interpolated['service']

      errors.add(
        :base,
        "The Weather Underground API has been disabled since Jan 1st 2018; please switch to OpenWeather."
      ) if wunderground?
    end

    def openweather
      if key_setup?
        onecall_endpoint = "http://api.openweathermap.org/data/2.5/onecall"
        lat, lng = coordinates
        response = HTTParty.get("%s?units=imperial&appid=%s&lat=%s&lon=%s&lang=%s" %
                                [onecall_endpoint, interpolated['api_key'], lat, lng, language.downcase])
        JSON.parse(response.body, object_class: OpenStruct).daily
      end
    end

    def dark_sky
      if key_setup?
        ForecastIO.api_key = interpolated['api_key']
        lat, lng = coordinates
        ForecastIO.forecast(lat, lng, params: {lang: language.downcase})['daily']['data']
      end
    end

    def model(which_day)
      if dark_sky?
        # AFAIK, there is no warning-level log messages. In any case, I'd like to log this from validate_options but
        # since the Agent doesn't exist yet, the Log record can't be created (no parent_id)
        log "NOTICE: The DarkSky API will be disabled at the end of 2021; please switch to OpenWeather." if dark_sky?
        dark_sky_model(which_day)
      elsif openweather?
        openweather_model(which_day)
      end
    end

    def dark_sky_model(which_day)
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

    def openweather_model(which_day)
      value = openweather[which_day - 1]
      if value
        timestamp = Time.at(value.dt)
        day = {
          'date' => {
            'epoch' => value.dt.to_s,
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
            'fahrenheit' => value.temp.max.round().to_s,
            'epoch' => nil,
            'fahrenheit_apparent' => value.feels_like.day.round().to_s,
            'epoch_apparent' => nil,
            'celsius' => ((5*(Float(value.temp.max) - 32))/9).round().to_s
          },
          'low' => {
            'fahrenheit' => value.temp.min.round().to_s,
            'epoch' => nil,
            'fahrenheit_apparent' => value.feels_like.night.round().to_s,
            'epoch_apparent' => nil,
            'celsius' => ((5*(Float(value.temp.min) - 32))/9).round().to_s
          },
          'conditions' => value.weather.first.description,
          'icon' => openweather_icon(value.weather.first.icon),
          'avehumidity' => (value.humidity * 100).to_i,
          'sunriseTime' => value.sunrise.to_s,
          'sunsetTime' => value.sunset.to_s,
          'moonPhase' => nil,
          'precip' => {
            'intensity' => value.rain.to_s.presence || '0',
            'intensity_max' => nil,
            'intensity_max_epoch' => nil,
            'probability' => nil,
            'type' => figure_rain_or_snow(value.rain, value.snow).presence,
          },
          'dewPoint' => value.dew_point.to_s,
          'avewind' => {
            'mph' => value.wind_speed.round().to_s,
            'kph' =>  (Float(value.wind_speed) * 1.609344).round().to_s,
            'degrees' => value.wind_deg.to_s
          },
          'visibility' => value.visibility.to_s,
          'cloudCover' => value.clouds.to_s,
          'pressure' => value.pressure.to_s,
          'ozone' => nil,
        }
        return day
      end
    end
  end
end
