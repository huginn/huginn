module Agents
  class AftershipAgent < Agent

    API_URL = 'https://api.aftership.com/v4/couriers/all'
    HEADERS = {"aftership-api-key"=>"api_key", "Content-Type"=>"application/json"}

    description <<-MD

      The Aftership agent allows you to track your shipment data from aftership.

      To be able to use the Aftership API, you need to generate an `API Key`.
      You can generate an api key by visiting `apps > app and click add` on aftership website. 

      The agent is limited to 600 reqs/min per account. You do need a paying plan to use their tracking feature.

      Required Options:

      * `Content-Type` application/json
      * `aftership_api_key` - YOUR_API_KEY.
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
      { 'aftership_api_key' => 'YOUR_API_KEY',
        'Content_Type' => 'application/json'
      }
    end

    def working?
      !recent_error_logs?
    end

    def validate_options
      errors.add(:base, "You need to specify a aftership api key") unless options['aftership-api-key'].present?
      #errors.add(:base, "Content-Type must be set to application/json") unless options['aftership-api-key'].present? && options['aftership-api-key'] == 'application/json'
    end

    def aftership
      HTTParty.get("https://api.aftership.com/v4/couriers/all", :headers => HEADERS)
    end

    def check
      data = {"body" => aftership.body, "message" => aftership.message}
      create_event :payload => data
    end
  end
end
