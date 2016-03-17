module Agents
  class QpxAgent < Agent

    default_schedule "every_10m"

    description <<-MD
      The QpxExpressAgent will tell you the minimum airline prices between a pair of cities, and within a certain period of time.

      Follow their introduction documentation here (https://developers.google.com/qpx-express/v1/prereqs#get-a-google-account) to retrieve an api key.
      After you get to the google chrome console and enabled qpx express api, you can choose `api key` credential to be created.
      For round trips please provide a `return_date`.
    MD

    def default_options
      {
        'qpx_api_key' => 'AIzaSyCMwV5ackABmIPX9pUgEPELXB_FiNKmem0',
        'date' => "2016-03-18",
        'origin' => "origin",
        'destination' => "destination",
        'return_date' => "2016-03-25"
      }
    end

    def validate_options
      errors.add(:base, "You need a qpx api key") unless options['qpx_api_key'].present?
      # errors.add(:base, "A origin must exist") unless options['origin'].present?
      # errors.add(:base, "A destination must exist") unless options['destination'].present?
      # errors.add(:base, "A date must exist") unless options['date'].present?
    end

    def working?
      !recent_error_logs?
    end

    HEADERS = {"Content-Type" => "application/json"}

    def check
      hash = {:request=>{:passengers=>{:adultCount=>1}, :slice=>[{:origin=>"BOS", :destination=>"LAX", :date=>"2016-03-20"}, {:origin=>"LAX", :destination=>"BOS", :date=>"2016-03-20"}]}}
      body = JSON.generate(hash)
      request = HTTParty.post(event_url, :body => @body, :headers => HEADERS)
      events = JSON.parse request.body
      create_event :payload => events
    end

    def event_url
      endpoint = 'https://www.googleapis.com/qpxExpress/v1/trips/search?key' + "#{URI.encode(interpolated[:qpx_api_key].to_s)}"
    end
  end
end
