module Agents
  class PostAgent < Agent
    cannot_create_events!

    default_schedule "never"

    description <<-MD
      A PostAgent receives events from other agents (or runs periodically), merges those events with the contents of `payload`, and sends the results as POST requests to a specified url. The `post_url` field must specify where you would like to send requests.  Please include the URI scheme (`http` or `https`).
    MD

    event_description "Does not produce events."

    def default_options
      {
        'post_url' => "http://www.example.com",
        'expected_receive_period_in_days' => 1,
        'payload' => {
          'key' => 'value'
        }
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      unless options['post_url'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, "post_url and expected_receive_period_in_days are required fields")
      end

      if options['payload'].present? && !options['payload'].is_a?(Hash)
        errors.add(:base, "if provided, payload must be a hash")
      end
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        post_data (options['payload'].presence || {}).merge(event.payload)
      end
    end

    def check
      post_data options['payload'].presence || {}
    end

    private

    def post_data(data)
      uri = URI.new(options[:post_url])
      req = Net::HTTP::Post.new(uri.request_uri)
      req.form_data = data
      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") { |http| http.request(req) }
    end
  end
end