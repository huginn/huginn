module Agents

  class HttpStatusAgent < Agent

    include WebRequestConcern
    include FormConfigurable

    can_dry_run!
    can_order_created_events!

    default_schedule "every_12h"

    form_configurable :url
    form_configurable :disable_redirect_follow, type: :array, values: ['true', 'false']

    description <<-MD
      The HttpStatusAgent will check a url and emit the resulting HTTP status code.

      Specify a `Url` and the Http Status Agent will produce an event with the http status code.

      The `disable redirect follow` option causes the Agent to not follow HTTP redirects. For example, setting this to `true` will cause an agent that receives a 301 redirect to `http://yahoo.com` to return a status of 301 instead of following the redirect and returning 200.
    MD

    event_description <<-MD
      Events will have the following fields:

          {
            "url": "...",
            "status": "..."
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

    def check
      check_this_url interpolated[:url]
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          check_this_url interpolated[:url]
        end
      end
    end

    private

    def check_this_url(url)
      if result = ping(url)
        create_event payload: { 'url' => url, 'status' => result.status.to_s, 'response_received' => true }
        memory['last_status'] = result.status.to_s
      else
        create_event payload: { 'url' => url, 'response_received' => false }
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
