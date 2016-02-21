require 'date'
require 'cgi'
module Agents
  class PublicTransportAgent < Agent
    cannot_receive_events!

    default_schedule "every_2m"

    description <<-MD
      The Public Transport Request Agent generates Events based on NextBus GPS transit predictions.

      Specify the following user settings:

      * agency (string)
      * stops (array)
      * alert_window_in_minutes (integer)

      First, select an agency by visiting [http://www.nextbus.com/predictor/adaAgency.jsp](http://www.nextbus.com/predictor/adaAgency.jsp) and finding your transit system.  Once you find it, copy the part of the URL after `?a=`.  For example, for the San Francisco MUNI system, you would end up on [http://www.nextbus.com/predictor/adaDirection.jsp?a=**sf-muni**](http://www.nextbus.com/predictor/adaDirection.jsp?a=sf-muni) and copy "sf-muni".  Put that into this Agent's agency setting.

      Next, find the stop tags that you care about. 

      Select your destination and lets use the n-judah route. The link should be [http://www.nextbus.com/predictor/adaStop.jsp?a=sf-muni&r=N](http://www.nextbus.com/predictor/adaStop.jsp?a=sf-muni&r=N) Once you find it, copy the part of the URL after `r=`.

      The link may not work, but we're just trying to get the part after the r=, so even if it gives an error, continue to the next step.

      To find the tags for the sf-muni system, for the N route, visit this URL:
      [http://webservices.nextbus.com/service/publicXMLFeed?command=routeConfig&a=sf-muni&r=**N**](http://webservices.nextbus.com/service/publicXMLFeed?command=routeConfig&a=sf-muni&r=N)

      The tags are listed as tag="1234". Copy that number and add the route before it, separated by a pipe '&#124;' symbol.  Once you have one or more tags from that page, add them to this Agent's stop list.  E.g,

          agency: "sf-muni"
          stops: ["N|5221", "N|5215"]

      Remember to pick the appropriate stop, which will have different tags for in-bound and out-bound.

      This Agent will generate predictions by requesting a URL similar to the following:

      [http://webservices.nextbus.com/service/publicXMLFeed?command=predictionsForMultiStops&a=sf-muni&stops=N&#124;5221&stops=N&#124;5215](http://webservices.nextbus.com/service/publicXMLFeed?command=predictionsForMultiStops&a=sf-muni&stops=N&#124;5221&stops=N&#124;5215)

      Finally, set the arrival window that you're interested in.  E.g., 5 minutes.  Events will be created by the agent anytime a new train or bus comes into that time window.

          alert_window_in_minutes: 5
    MD

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

    def check_url
      stop_query = URI.encode(interpolated["stops"].collect{|a| "&stops=#{a}"}.join)
      "http://webservices.nextbus.com/service/publicXMLFeed?command=predictionsForMultiStops&a=#{interpolated["agency"]}#{stop_query}"
    end

    def stops
      interpolated["stops"].collect{|a| a.split("|").last}
    end

    def check
      hydra = Typhoeus::Hydra.new
      request = Typhoeus::Request.new(check_url, :followlocation => true)
      request.on_success do |response|
        page = Nokogiri::XML response.body
        predictions = page.css("//prediction")
        predictions.each do |pr|
          parent = pr.parent.parent
          vals = {"routeTitle" => parent["routeTitle"], "stopTag" => parent["stopTag"]}
          if pr["minutes"] && pr["minutes"].to_i < interpolated["alert_window_in_minutes"].to_i
            vals = vals.merge Hash.from_xml(pr.to_xml)
            if not_already_in_memory?(vals)
              create_event(:payload => vals)
              log "creating event..."
              update_memory(vals)
            else
              log "not creating event since already in memory"
            end
          end
        end
      end
      hydra.queue request
      hydra.run
    end

    def update_memory(vals)
      add_to_memory(vals)
      cleanup_old_memory
    end

    def cleanup_old_memory
      self.memory["existing_routes"] ||= []
      self.memory["existing_routes"].reject!{|h| h["currentTime"].to_time <= (Time.now - 2.hours)}
    end

    def add_to_memory(vals)
      self.memory["existing_routes"] ||= []
      self.memory["existing_routes"] << {"stopTag" => vals["stopTag"], "tripTag" => vals["prediction"]["tripTag"], "epochTime" => vals["prediction"]["epochTime"], "currentTime" => Time.now}
    end

    def not_already_in_memory?(vals)
      m = self.memory["existing_routes"] || []
      m.select{|h| h['stopTag'] == vals["stopTag"] &&
                h['tripTag'] == vals["prediction"]["tripTag"] &&
                h['epochTime'] == vals["prediction"]["epochTime"]
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
