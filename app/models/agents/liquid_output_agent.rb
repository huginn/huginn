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

    def feed_ttl
      (interpolated['ttl'].presence || 60).to_i
    end

    def feed_title
      interpolated['template']['title'].presence || "#{name} Event Feed"
    end

    def feed_link
      interpolated['template']['link'].presence || "https://#{ENV['DOMAIN']}"
    end

    def feed_url(options = {})
      interpolated['template']['self'].presence ||
        feed_link + Rails.application.routes.url_helpers.
                    web_requests_path(agent_id: id || ':id',
                                      user_id: user_id,
                                      secret: options[:secret],
                                      format: options[:format])
    end

    def feed_icon
      interpolated['template']['icon'].presence || feed_link + '/favicon.ico'
    end

    def feed_description
      interpolated['template']['description'].presence || "A feed of Events received by the '#{name}' Huginn Agent"
    end

    def receive(incoming_events)
      memory['last_event'] = incoming_events[-1].payload
    end

    def receive_web_request(params, method, format)
      unless interpolated['secrets'].include?(params['secret'])
        if format =~ /json/
          return [{ error: "Not Authorized" }, 401]
        else
          return ["Not Authorized", 401]
        end
      end

      template = Liquid::Template.parse(options['content'] || "")
      content = template.render(memory['last_event'] || {})

      mime_type = options['mime_type'].present? ? options['mime_type'] : 'text/html'
      return [content, 200, mime_type]
    end
  end
end
