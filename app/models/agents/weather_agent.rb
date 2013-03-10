require 'date'

module Agents
  class WeatherAgent < Agent
    cannot_receive_events!

    description <<-MD
      The WeatherAgent created an event for the following day's weather at `zipcode`.
    MD

    event_description <<-MD
      Events look like this:

          {
            :zipcode => 12345,
            :date => { :epoch=>"1357959600", :pretty=>"10:00 PM EST on January 11, 2013" },
            :high => { :fahrenheit=>"64", :celsius=>"18" },
            :low => { :fahrenheit=>"52", :celsius=>"11" },
            :conditions => "Rain Showers",
            :icon=>"rain",
            :icon_url => "http://icons-ak.wxug.com/i/c/k/rain.gif",
            :skyicon => "mostlycloudy",
            :pop => 80,
            :qpf_allday => { :in=>0.24, :mm=>6.1 },
            :qpf_day => { :in=>0.13, :mm=>3.3 },
            :qpf_night => { :in=>0.03, :mm=>0.8 },
            :snow_allday => { :in=>0, :cm=>0 },
            :snow_day => { :in=>0, :cm=>0 },
            :snow_night => { :in=>0, :cm=>0 },
            :maxwind => { :mph=>15, :kph=>24, :dir=>"SSE", :degrees=>160 },
            :avewind => { :mph=>9, :kph=>14, :dir=>"SSW", :degrees=>194 },
            :avehumidity => 85,
            :maxhumidity => 93,
            :minhumidity => 63
          }
    MD

    default_schedule "midnight"

    def working?
      (event = event_created_within(2.days)) && event.payload.present?
    end

    def wunderground
      Wunderground.new("your-api-key")
    end

    def default_options
      { :zipcode => "94103" }
    end

    def validate_options
      errors.add(:base, "zipcode is required") unless options[:zipcode].present?
    end

    def check
      wunderground.forecast_for(options[:zipcode])["forecast"]["simpleforecast"]["forecastday"].each do |day|
        if is_tomorrow?(day)
          create_event :payload => day.merge(:zipcode => options[:zipcode])
        end
      end
    end

    def is_tomorrow?(day)
      Time.zone.at(day["date"]["epoch"].to_i).to_date == Time.zone.now.tomorrow.to_date
    end
  end
end