module Agents
  class LiquidOutputAgent < Agent
    include WebRequestConcern
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_events!

    DATE_UNITS = %w[second seconds minute minutes hour hours day days week weeks month months year years]

    description  do
      <<-MD
        The Liquid Output Agent outputs events through a Liquid template you provide.  Use it to create a HTML page, or a json feed, or anything else that can be rendered as a string from your stream of Huginn data. 

        This Agent will output data at:

        `https://#{ENV['DOMAIN']}#{Rails.application.routes.url_helpers.web_requests_path(agent_id: ':id', user_id: user_id, secret: ':secret', format: :any_extension)}`

        where `:secret` is the secret specified in your options.  You can use any extension you wish.

        Options:

          * `secret` - A token that the requestor must provide for light-weight authentication.
          * `expected_receive_period_in_days` - How often you expect data to be received by this Agent from other Agents.
          * `content` - The content to display when someone requests this page.
          * `mime_type` - The mime type to use when someone requests this page.
          * `mode` - The behavior that determines what data is passed to the Liquid template.
          * `event_limit` - A limit applied to the events passed to a template when in "Last X events" mode. Can be a count like "1", or an amount of time like "1 day" or "5 minutes".

        # Liquid Templating

        The content you provide will be run as a Liquid template. The data from the last event received will be used when processing the Liquid template.

        # Modes

        ### Merge events

          The data for incoming events will be merged. So if two events come in like this:

```
{ 'a' => 'b',  'c' => 'd'}
{ 'a' => 'bb', 'e' => 'f'}
```

          The final result will be:

```
{ 'a' => 'bb', 'c' => 'd', 'e' => 'f'}
```

        This merged version will be passed to the Liquid template.

        ### Last event in

          The data from the last event will be passed to the template.

        ### Last X events

          All of the events received by this agent will be passed to the template as ```events```.

          The number of events can be controlled via the ```event_limit``` option.
          If ```event_limit``` is an integer X, the last X events will be passed
          to the template.  If ```event_limit``` is an integer with a unit of
          measure like "1 day" or "5 minutes" or "9 years", a date filter will
          be applied to the events passed to the template.  If no ```event_limit```
          is provided, then all of the events for the agent will be passed to
          the template.

      MD
    end

    def default_options
      {
        "secret" => "a-secret-key",
        "expected_receive_period_in_days" => 2,
        "content" => 'This is a Liquid template. Include variables from your last event, like {{this}} and {{that}}.',
        "mime_type" => 'text/html',
        "mode" => 'Last event in',
        "event_limit" => '',
      }
    end

    form_configurable :secret
    form_configurable :expected_receive_period_in_days
    form_configurable :content, type: :text
    form_configurable :mime_type
    form_configurable :mode, type: :array, values: [ 'Last event in', 'Merge events', 'Last X events']
    form_configurable :event_limit

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      if options['secret'].present?
        case options['secret']
        when %r{[/.]}
          errors.add(:base, "secret may not contain a slash or dot")
        when String
        else
          errors.add(:base, "secret must be a string")
        end
      else
        errors.add(:base, "Please specify one secret for 'authenticating' incoming feed requests")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def receive(incoming_events)
      return unless ['Merge events', 'Last event in'].include?(options['mode'])
      memory['last_event'] ||= {}
      incoming_events.each do |event|
        case options['mode']
        when 'Merge events'
          memory['last_event'] = memory['last_event'].merge(event.payload)
        else
          memory['last_event'] = event.payload
        end
      end
    end

    def receive_web_request(params, method, format)
      valid_authentication?(params) ? [liquified_content, 200, mime_type]
                                    : [unauthorized_content(format), 401]
    end

    private

    def unauthorized_content(format)
      format =~ /json/ ? { error: "Not Authorized" }
                       : "Not Authorized"
    end

    def valid_authentication?(params)
      interpolated['secret'] == params['secret']
    end

    def mime_type
      options['mime_type'].present? ? options['mime_type'] : 'text/html'
    end

    def liquified_content
      template = Liquid::Template.parse(options['content'] || "")
      template.render(data_for_liquid_template)
    end

    def data_for_liquid_template
      case options['mode'].to_s.downcase
      when 'last x events'
        events = received_events
        events = events.where('events.created_at > ?', date_limit) if date_limit
        events = events.limit(count_limit) if count_limit
        events = events.to_a.map { |x| x.payload }
        { 'events' => events }
      else
        memory['last_event'] || {}
      end
    end

    def count_limit
      Integer(options['event_limit']) rescue 5000
    end

    def date_limit
      return nil unless options['event_limit'].to_s.include?(' ')
      value, unit = options['event_limit'].split(' ')
      value = Integer(value) rescue nil
      return nil unless value
      unit = unit.to_s.downcase
      return nil unless DATE_UNITS.include?(unit)
      value.send(unit.to_sym).ago
    end

  end
end
