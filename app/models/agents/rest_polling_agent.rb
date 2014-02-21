require 'em-http'
require 'badgerfish'
require 'json'

module Agents
  class RestPollingAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!
    continuous!

    description <<-MD
      Does long polling on a rest API url. The resulting type should be json or XML (which will be translated to json).
    MD

    event_description "REST event"

    def default_options
      {  
          'url' => "http://some.polling/url",
          'type' => "xml"
      }
    end

    def em_start
      t = Time.now
      http = EM::HttpRequest.new(options['url']).get
      http.errback {
          error "Failed: #{http.error}"
          if !@destroyed
            pp "errback again "+name
            if Time.now - t > 0.1
              em_start
            else
              EM.add_timer(1) {
                  em_start
              }
            end
          end
        }
      http.callback {
          if !@destroyed
            pp "callback again"+name
            puts http.response
            if http.response_header.status == 200
              begin
                if options['type'] == "json"
                  pld = JSON.parse(http.response)
                else
                  pld = Badgerfish::Parser.new.load(http.response)
                end
                create_event :payload => pld
              rescue
                error "Parsing error"
              end
            else
              error "Failed #{http.response_header.status}: #{http.response_header}"
            end
            if Time.now - t > 0.1
              em_start
            else
              EM.add_timer(1) {
                  em_start
              }
            end
          end
        }
    end

    def em_stop
      @destroyed = true
    end

    def working?
      true
    end

    def validate_options
      errors.add(:base, "url and type are required") unless options['type'].present? && options['url'].present?
      if options['type'] != 'json' && options['type'] != 'xml'
        errors.add(:base, "unrecognized type")
      end
    end
  end
end
