require 'uri'

module Agents
  class AftershipAgent < Agent

    API_URL = 'https://api.aftership.com/v4'
    HEADERS = {"aftership-api-key"=> "apikey", "Content-Type"=>"application/json"}

    description <<-MD

      The Aftership agent allows you to track your shipment data from aftership and emit them into events.

      To be able to use the Aftership API, you need to generate an `API Key`.
      You can generate an api key by visiting `apps > app and click add` on aftership website. 

      The agent is limited to 600 reqs/min per account. You do need a paying plan to use their tracking feature.

      If you are requesting tracking data from aftership. You have to put in a specific url for get_url in default options. 

      The options are `/trackings/export` to get tracking results for backup purposes, `/trackings/:slug/:tracking_number` to get tracking 

      for a single tracking number and `trackings` to get all of your trackings.

      Required Options:

      * `Content-Type` application/json
      * `aftership_api_key` - YOUR_API_KEY.
      * `a certain request whether it be get or put or post`
    MD

    event_description <<-MD
      Events look like this:

    {
      "meta": {
        "code": 200
      },
      "data": {
        "couriers": [
           { ... }, 
           { ... },
           { ... }
           ] 
       }
     }
      MD

    def default_options
      { 'api_key' => 'YOUR_API_KEY',
        'Content_Type' => 'application/json',
        'get_url' => '/trackings'
      }
    end

    def uri
      #there may be an updated version
      uri = URI.parse('https://api.aftership.com/v4')
      #uri.query = [uri.query, '/trackings' ].compact.join()
      uri.query = [uri.query, interpolated['get_url'] ].compact.join()
      uri.to_s.gsub('?','')
    end

    def working?
      !recent_error_logs?
    end

    def validate_options
      #errors.add(:base, "You need to specify a aftership api key") unless options['aftership-api-key'].present?
      errors.add(:base, "Content-Type must be set to application/json") unless options['Content_Type'].present? && options['Content_Type'] == 'application/json'
      #only one put or request can be requested
    end

    def request
      HTTParty.get(uri, :headers => HEADERS)
    end

    def check
      data = {"body" => request.body, "message" => request.message}
      create_event :payload => data
    end
  end
end
