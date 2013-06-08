module Agents
    class PostAgent < Agent
        cannot_be_scheduled!

        description <<-MD
            Post Agent receives events from other agents and send those events as the contents of a post request to a specified url. `post_url` field must specify where you would like to receive post requests and do not forget to include URI scheme(`http` or `https`)
        MD

        event_description <<-MD
            Does not produce any event.
        MD

        def default_options
            {
                :post_url => "http://www.example.com",
                :expected_receive_period_in_days => 1
            }
        end

        def working?
            last_receive_at && last_receive_at > options[:expected_receive_period_in_days].to_i.days.ago
        end

        def validate_options
            unless options[:post_url].present? && options[:expected_receive_period_in_days].present? 
                errors.add(:base, "post_url and expected_receive_period_in_days are required fields")
            end
        end

        def post_event(uri,event)
            req = Net::HTTP::Post.new(uri.request_uri)
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