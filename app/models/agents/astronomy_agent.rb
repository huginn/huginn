require 'date'
require 'cgi'
require 'json'

module Agents
  class AstronomyAgent < Agent
    cannot_receive_events!

    EVENT_TRIGGERS = ["sunrise", "sunset", "moonrise", "moonset"]

    description <<-MD
      The AstronomyAgent creates an event for the following day's moon sunrise and sundown for a given location.

      The `location` can be a US zipcode, or any location that Wunderground supports.  To find one, search [wunderground.com](http://wunderground.com) and copy the location part of the URL.  For example, a result for San Francisco gives `http://www.wunderground.com/US/CA/San_Francisco.html` and London, England gives `http://www.wunderground.com/q/zmw:00000.1.03772`.  The locations in each are `US/CA/San_Francisco` and `zmw:00000.1.03772`, respectively.

      Events is optional, but if specified, limits the event generation to the listed events. Available events from this agent are: moonrise, moonset, sunrise, sunset

      You must setup an [API key for Wunderground](http://www.wunderground.com/weather/api/) in order to use this Agent.
    MD

    event_description <<-MD
      Events look like this:

          {
            emits_at: 2014-03-31T07:05:00-04:00
            event: sunrise
          }
    MD

    default_schedule "2m"

    def default_options
      {
        'api_key' => 'your-key',
        'location' => '94103',
        'events' => [ "sunrise", "sunset" ]
      }
    end

    def validate_options
      errors.add(:base, "location is required") unless options["location"].present?
      if key_setup?
         #f = wunderground.astronomy_for(options['location'])
         #pp "testing setup"
         #errors.add(:base, "There was an error contacting wunderground: "+f['response']['error']['description']) if f['response']['error']
         true
      else
         errors.add(:base, "api_key is required")
      end
      if options["events"].empty?
         options['events'] = EVENT_TRIGGERS
      end
    end

    def key
      return unless key_setup?
      if options['api_key'].present? && options['api_key'] != "your-key"
         return options['api_key']
      elsif credential('wunderground_api_key').present?
         return credential('wunderground_api_key')
      end
    end

    def key_setup?
      (options['api_key'].present? && options['api_key'] != "your-key") or
         credential("wunderground_api_key").present?
    end

    def working?
      event_created_within?(2) && !recent_error_logs?
    end

    def wunderground
      Wunderground.new(key) if key_setup?
    end

    def check
      if key_setup?
        a = wunderground.astronomy_for(options['location'])
        if a
           self.memory['astro'] = a
           n = Time.now

           event_time = {}
           event_time['moonrise'] = Time.new(
                 n.year, n.month, n.day, 
                 a['moon_phase']['sunrise']['hour'], a['moon_phase']['sunrise']['minute']
           )
           event_time['moonset'] = Time.new(
                 n.year, n.month, n.day, 
                 a['moon_phase']['sunset']['hour'], a['moon_phase']['sunset']['minute']
           )

           event_time['sunrise'] = Time.new(
                 n.year, n.month, n.day, 
                 a['sun_phase']['sunrise']['hour'], a['sun_phase']['sunrise']['minute']
           )
           event_time['sunset'] = Time.new(
                 n.year, n.month, n.day, 
                 a['sun_phase']['sunset']['hour'], a['sun_phase']['sunset']['minute']
           )

           EVENT_TRIGGERS.each { |ev|
              if options["events"].include?(ev) and event_time[ev] > n
                 create_event(
                    :payload => {
                       :emits_at => event_time[ev],
                       :message => ev
                    }.to_json
                 )
              end
           }
        end
      end
    end
  end
end
