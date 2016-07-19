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

        where `:secret` is thel secret specified in your options.  You can use any extension you wish.

        Options:

          * `secrets` - An array of tokens that the requestor must provide for light-weight authentication.
          * `expected_receive_period_in_days` - How often you expect data to be received by this Agent from other Agents.
          * `content` - The content to display when someone requests this page.
          * `mime_type` - The mime type to use when someone requests this page.

        # Liquid Templating

        The content you provide will be run as a Liquid template. The data from the last event received will be used when processing the Liquid template.
      MD
    end

    def default_options
      {
        "secrets" => "a-secret-key",
        "expected_receive_period_in_days" => 2,
        "content" => 'This is a Liquid template. Include variables from your last event, like {{this}} and {{that}}.',
        "mime_type" => 'text/html',
      }
    end

    form_configurable :secrets
    form_configurable :expected_receive_period_in_days
    form_configurable :content, type: :text
    form_configurable :mime_type

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def validate_options
      if options['secrets'].present?
        case options['secrets']
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
      memory['last_event'] ||= {}
      incoming_events.each do |event|
        case options['mode']
        when 'merge'
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
      interpolated['secrets'] == params['secret']
    end

    def mime_type
      options['mime_type'].present? ? options['mime_type'] : 'text/html'
    end

    def liquified_content
      template = Liquid::Template.parse(options['content'] || "")
      template.render(memory['last_event'] || {})
    end

  end
end
