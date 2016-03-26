module Agents
  class SimpleMetaAgent < Agent
    cannot_be_scheduled!
    can_dry_run!
    gem_dependency_check { defined? MetaInspector }

    description <<-MD
      The SimpleMetaAgent scrapes meta from `url`, merges a meta object with the event.payload and re-emits the updated event.

      #{'## Include `metainspector` in your Gemfile to use this Agent!' if dependencies_missing?}

      `url` is the URL to extract meta from. You can use liquid templating in the `url` to extract from the incoming event. Have a look at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) for details.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
    MD

    event_description <<-MD
      Incomining events are merged with a `meta` object provided by the [metainspector gem](https://github.com/jaimeiniesta/metainspector)(meta object is the same as `page.to_hash` response) and should look like:

          {
            incoming_url: 'http://angularjobs.com',
            ... all fields from the incoming event merged with (below)...
            title: "AngularJS Jobs + JavaScript Developer Community Resources",
            best_title: "AngularJS Jobs + JavaScript Developer Community Resources",
            description: "Top JavaScript Engineers seeking Contract & Full-time work...",
            meta_tags: {
              name: {
                description: [
                  "Businesses, startups & organizations find Senior, Full-Stack, Lead & Architect candidates with AngularJS, React, jQuery & NodeJS experience."
                ],
                keywords: [
                  "AngularJS, JavaScript, React, Ember, Rails, Talent, Hiring, Interviewing"
                ]
              }
            }
          }

        ... see [metainspector](https://github.com/jaimeiniesta/metainspector) to learn more about the merged fields.
    MD

    def default_options
      {
        url: '{{url}}',
        expected_receive_period_in_days: "10"
      }
    end

    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
      unless options['url'].present?
        errors.add(:base, "Please provide 'url' to indicate which value to analyze for collecting top events.")
      end
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        opts = interpolated(event)
        if (url = opts['url']) && (url =~ /\A#{URI::regexp(['http', 'https'])}\z/)
          begin
            page = MetaInspector.new(url, connection_timeout: 10, read_timeout: 10, retries: 0)
          rescue Faraday::TimeoutError
            log "Timeout error event ##{event.id}: #{url}"
          rescue FaradayMiddleware::RedirectLimitReached
            log "Redirect limit reached event ##{event.id}: #{url}"
          else
            create_event payload: event.payload.merge(meta: page.to_hash, untracked_url: page.untracked_url)
          end
        else
          log "Invalid URL: #{url}"
        end
      end
    end
  end
end
