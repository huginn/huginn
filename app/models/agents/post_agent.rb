module Agents
  class PostAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
       Post Agent receives events from other agents and send those events as the contents of a post request to a specified url. `post_url` field must specify where you would like to receive post requests and do not forget to include URI scheme (`http` or `https`)
       
       Options:

       * `post_url` - The url for a post request. 
       * `expected_receive_period_in_days` - How often you expect data to be received by this Agent from other Agents.
       * `headers` (optional) - Hash of http headers to be sent.
    MD

    event_description "Does not produce events."

    def default_options
      {
        'post_url' => "http://www.example.com",
        'expected_receive_period_in_days' => 1,
        'headers' => {}
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      unless options['post_url'].present? && options['expected_receive_period_in_days'].present?
        errors.add(:base, "post_url and expected_receive_period_in_days are required fields")
      end
      if options['headers'].present? && options['headers'].class != Hash
        errors.add(:base, "headers must be a type of Hash")
      end
    end

    def post_event(uri, event)
      headers = options['headers']
      req = Net::HTTP::Post.new(uri.request_uri, headers)
      req.form_data = event
      Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == "https") { |http| http.request(req) }
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        uri = URI options[:post_url]
        post_event uri, event.payload
      end
    end
  end
end
