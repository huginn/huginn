require 'em-http'
require 'cobravsmongoose'
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
          if Time.now - t > 0.1
            em_start
          else
            EM.add_timer(1) {
                em_start
              }
          end
        }
      http.callback {
          puts http.response
          if options['type'] == "json"
            pld = JSON.parse(http.response)
          else
            pld = CobraVsMongoose.xml_to_hash(http.response)
          end
          create_event :payload => pld
          if Time.now - t > 0.1
            em_start
          else
            EM.add_timer(1) {
                em_start
              }
          end
        }
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
