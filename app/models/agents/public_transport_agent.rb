require 'date'
require 'cgi'
module Agents
  class PublicTransportAgent < Agent
    cannot_receive_events!
    description <<-MD
      Specify the following user settings:
        - stops (array)
        - agency (string)
        - alert_window_in_minutes (integer)

        This Agent generates Events based on NextBus GPS transit predictions.  First, select an agency by visiting http://www.nextbus.com/predictor/agencySelector.jsp and finding your transit system.  Once you find it, copy the part of the URL after `?a=`.  For example, for the San Francisco MUNI system, you would end up on http://www.nextbus.com/predictor/stopSelector.jsp?a=sf-muni and copy "sf-muni".  Put that into this Agent's agency setting.

      Next, find the stop tags that you care about.  To find the tags for the sf-muni system, for the N route, visit this URL:
      http://webservices.nextbus.com/service/publicXMLFeed?command=routeConfig&a=sf-muni&r=N

      The tags are listed as tag="1234". Copy that number and add the route before it, separated by a pipe '&#124;' symbol.  Once you have one or more tags from that page, add them to this Agent's stop list.  E.g,

          agency: "sf-muni"
          stops: ["N|5221", "N|5215"]

      This Agent will generate predictions by requesting a URL similar to the following:

      http://webservices.nextbus.com/service/publicXMLFeed?command=predictionsForMultiStops&a=sf-muni&stops=N|5221&stops=N|5215

      Finally, set the arrival window that you're interested in.  E.g., 5 minutes.  Events will be created by the agent anytime a new train or bus comes into that time window.

    alert_window_in_minutes: 5

 This memory should get cleaned up when timestamp is older than an hour (or something) so that it doesn't fill up all of the Agent's memory.
    MD


    default_schedule "every_2m"

    event_description <<-MD
    Events look like this:
      { "routeTitle":"N-Judah",
        "stopTag":"5215",
        "prediction":
           {"epochTime":"1389622846689",
            "seconds":"3454","minutes":"57","isDeparture":"false",
            "affectedByLayover":"true","dirTag":"N__OB4KJU","vehicle":"1489",
            "block":"9709","tripTag":"5840086"
            }
      }
    MD
    def session
      @session ||= Patron::Session.new
      @session.connect_timeout = 10
      @session.timeout = 60
      @session.headers['Accept-Language'] = 'en-us,en;q=0.5'
      @session.headers['User-Agent'] = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_4; en-US) AppleWebKit/534.12 (KHTML, like Gecko) Chrome/9.0.584.0 Safari/534.12"
      @session
    end

    def check_url
      stop_query = URI.encode(options["stops"].collect{|a| "&stops=#{a}"}.join)
      "http://webservices.nextbus.com/service/publicXMLFeed?command=predictionsForMultiStops&a=#{options["agency"]}#{stop_query}"
    end

    def stops
      options["stops"].collect{|a| a.split("|").last}
    end
    def check
      page = session.get(check_url)
      page = Nokogiri::XML page.body
      predictions = page.css("//prediction")
      predictions.each do |pr|
        parent = pr.parent.parent
        vals = {routeTitle: parent["routeTitle"], stopTag: parent["stopTag"]}
        if pr["minutes"] && pr["minutes"].to_i < options["alert_window_in_minutes"].to_i
          vals = vals.merge Hash.from_xml(pr.to_xml)
          if not_already_in_memory?(vals)
            create_event(:payload => vals)
            add_to_memory(vals)
          else
          end
        end
      end
    end
    def add_to_memory(vals)
      self.memory["existing_routes"] ||= []
      self.memory["existing_routes"] << {stopTag: vals["stopTag"], tripTag: vals["prediction"]["tripTag"], epochTime: vals["prediction"]["epochTime"], currentTime: Time.now}
    end
    def not_already_in_memory?(vals)
      m = self.memory["existing_routes"]
      m.select{|h| h[:stopTag] == vals["stopTag"] &&
                h[:tripTag] == vals["prediction"]["tripTag"] &&
                h[:epochTime] == vals["prediction"]["epochTime"]
              }.count == 0
    end
    def default_options
      {
        agency: "sf-muni",
        stops: ["N|5221", "N|5215"],
        alert_window_in_minutes: 5
      }
    end

    def validate_options
      errors.add(:base, 'agency is required') unless options['agency'].present?
      errors.add(:base, 'alert_window_in_minutes is required') unless options['alert_window_in_minutes'].present?
      errors.add(:base, 'stops are required') unless options['stops'].present?
    end
    def working?
      event_created_within?(2) && !recent_error_logs?
    end
  end
end
