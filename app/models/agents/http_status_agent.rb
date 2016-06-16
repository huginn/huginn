module Agents

  class HttpStatusAgent < Agent

    include WebRequestConcern
    include FormConfigurable

    can_dry_run!
    can_order_created_events!

    default_schedule "every_12h"

    form_configurable :url
    form_configurable :disable_redirect_follow, type: :array, values: ['true', 'false']
    form_configurable :headers_to_save

    description <<-MD
      The HttpStatusAgent will check a url and emit the resulting HTTP status code with the time that it waited for a reply. Additionally, it will optionally emit the value of one or more specified headers.

      Specify a `Url` and the Http Status Agent will produce an event with the HTTP status code. If you specify one or more `Headers to save` (comma-delimited) as well, that header or headers' value(s) will be included in the event.

      The `disable redirect follow` option causes the Agent to not follow HTTP redirects. For example, setting this to `true` will cause an agent that receives a 301 redirect to `http://yahoo.com` to return a status of 301 instead of following the redirect and returning 200.
    MD

    event_description <<-MD
      Events will have the following fields:

          {
            "url": "...",
            "status": "...",
            "elapsed_time": "...",
            "headers": {
              "...": "..."
            }
          }
    MD

    def working?
      memory['last_status'].to_i > 0
    end

    def default_options
      {
        'url' => "http://google.com",
        'disable_redirect_follow' => "true",
      }
    end

    def validate_options
      errors.add(:base, "a url must be specified") unless options['url'].present?
    end

    def header_array(str)
      (str || '').split(',').map(&:strip)
    end

    def check
      check_this_url interpolated[:url], header_array(interpolated[:headers_to_save])
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          check_this_url interpolated[:url], header_array(interpolated[:headers_to_save])
        end
      end
    end

    private

    def check_this_url(url, local_headers)
      # Track time
      measured_result = TimeTracker.track { ping(url) }

      payload = { 'url' => url, 'response_received' => false, 'elapsed_time' => measured_result.elapsed_time }

      # Deal with failures
      if measured_result.result
        payload.merge!({ 'response_received' => true, 'status' => measured_result.status.to_s })
        # Deal with headers
        if local_headers.present?
          header_results = measured_result.result.headers.select {|header, value| local_headers.include?(header)}
          # Fill in headers that we wanted, but weren't returned
          local_headers.each { |header| header_results[header] = nil unless header_results.has_key?(header) }
          payload.merge!({ 'headers' => header_results })
        end
        create_event payload: payload
        memory['last_status'] = measured_result.status.to_s
      else
        create_event payload: payload
        memory['last_status'] = nil
      end

    end

    def ping(url)
      result = faraday.get url
      result.status > 0 ? result : nil
    rescue
      nil
    end
  end

end
