module Agents
  class WitaiAgent < Agent
    cannot_be_scheduled!
    no_bulk_receive!

    description <<-MD
      The `wit.ai` agent receives events, sends a text query to your `wit.ai` instance and generates outcome events.

      Fill in `Server Access Token` of your `wit.ai` instance. Use [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) to fill query field.
      
      `expected_receive_period_in_days` is the expected number of days by which agent should receive events. It helps in determining if the agent is working.
    MD

    event_description <<-MD

    Every event have `outcomes` key with your payload as value. Sample event:

        {"outcome" : [
          {"_text" : "set temperature to 34 degrees at 11 PM",
           "intent" : "get_temperature",
           "entities" : {
             "temperature" : [
             {
               "type" : "value",
               "value" : 34,
               "unit" : "degree"
             }],
             "datetime" : [
             {
               "grain" : "hour",
               "type" : "value",
               "value" : "2015-03-26T21:00:00.000-07:00"
             }]},
             "confidence" : 0.556
           }]}
    MD

    def default_options
      {
       'server_access_token' => 'xxxxx',
       'expected_receive_period_in_days' => 2,
       'query' => '{{xxxx}}'
      }
    end

    def working?
      !recent_error_logs? && most_recent_event && event_created_within?(interpolated['expected_receive_period_in_days'])
    end

    def validate_options
      unless %w[server_access_token query expected_receive_period_in_days].all? { |field| options[field].present? }
        errors.add(:base, 'All fields are required')
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolated_event = interpolated event
        response = HTTParty.get query_url(interpolated_event[:query]), headers
        create_event 'payload' => {
          'outcomes' => JSON.parse(response.body)['outcomes']
        }
      end
    end

    private
      def api_endpoint
        'https://api.wit.ai/message?v=20141022&q='
      end

      def query_url(query)
        api_endpoint + URI.encode(query)
      end

      def headers
        #oauth
        {:headers => {'Authorization' => 'Bearer ' + interpolated[:server_access_token]}}
      end
  end
end
