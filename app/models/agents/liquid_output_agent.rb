module Agents
  class LiquidOutputAgent < Agent
    include WebRequestConcern
    include FormConfigurable

    cannot_be_scheduled!

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
      MD
    end

    def default_options
      {
        "secret" => "a-secret-key",
        "expected_receive_period_in_days" => 2,
        "content" => 'This is a Liquid template. Include variables from your last event, like {{this}} and {{that}}.',
        "mime_type" => 'text/html',
        "mode" => 'Last event in',
      }
    end

    form_configurable :secret
    form_configurable :expected_receive_period_in_days
    form_configurable :content, type: :text
    form_configurable :mime_type
    form_configurable :mode, type: :array, values: [ 'Last event in', 'Merge events']

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
      case options['mode']
      when 'Last X events'
        events = received_events.order(id: :desc)
        events = events.limit(count_limit) if count_limit
        events = events.select { |x| x.created_at > date_limit } if date_limit
        events = events.to_a.map { |x| x.payload }
        { 'events' => events }
      else
        memory['last_event'] || {}
      end
    end

    def count_limit
      Integer(options['event_limit']) rescue nil
    end

    def date_limit
      return nil unless options['event_limit'].to_s.include?(' ')
      splits = options['event_limit'].split(' ')
      splits[0].to_i.send(splits[1].to_sym).ago
    end

  end
end
