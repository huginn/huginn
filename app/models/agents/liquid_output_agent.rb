module Agents
  class LiquidOutputAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_events!

    DATE_UNITS = %w[second seconds minute minutes hour hours day days week weeks month months year years]

    description  do
      <<~MD
        The Liquid Output Agent outputs events through a Liquid template you provide.  Use it to create a HTML page, or a json feed, or anything else that can be rendered as a string from your stream of Huginn data.

        This Agent will output data at:

        `https://#{ENV['DOMAIN']}#{Rails.application.routes.url_helpers.web_requests_path(agent_id: ':id', user_id:, secret: ':secret', format: :any_extension)}`

        where `:secret` is the secret specified in your options.  You can use any extension you wish.

        Options:

        * `secret` - A token that the requestor must provide for light-weight authentication.
        * `expected_receive_period_in_days` - How often you expect data to be received by this Agent from other Agents.
        * `content` - The content to display when someone requests this page.
        * `line_break_is_lf` - Use LF as line breaks instead of CRLF.
        * `mime_type` - The mime type to use when someone requests this page.
        * `response_headers` - An object with any custom response headers. (example: `{"Access-Control-Allow-Origin": "*"}`)
        * `mode` - The behavior that determines what data is passed to the Liquid template.
        * `event_limit` - A limit applied to the events passed to a template when in "Last X events" mode. Can be a count like "1", or an amount of time like "1 day" or "5 minutes".

        # Liquid Templating

        The content you provide will be run as a [Liquid](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) template. The data from the last event received will be used when processing the Liquid template.

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

        All of the events received by this agent will be passed to the template as the `events` array.

        The number of events can be controlled via the `event_limit` option.
        If `event_limit` is an integer X, the last X events will be passed to the template.
        If `event_limit` is an integer with a unit of measure like "1 day" or "5 minutes" or "9 years", a date filter will be applied to the events passed to the template.
        If no `event_limit` is provided, then all of the events for the agent will be passed to the template.

        For performance, the maximum `event_limit` allowed is 1000.
      MD
    end

    def default_options
      content = <<~EOF
        When you use the "Last event in" or "Merge events" option, you can use variables from the last event received, like this:

        Name: {{name}}
        Url:  {{url}}

        If you use the "Last X Events" mode, a set of events will be passed to your Liquid template.  You can use them like this:

        <table class="table">
          {% for event in events %}
            <tr>
              <td>{{ event.title }}</td>
              <td><a href="{{ event.url }}">Click here to see</a></td>
            </tr>
          {% endfor %}
        </table>
      EOF
      {
        "secret" => "a-secret-key",
        "expected_receive_period_in_days" => 2,
        "mime_type" => 'text/html',
        "mode" => 'Last event in',
        "event_limit" => '',
        "content" => content,
      }
    end

    form_configurable :secret
    form_configurable :expected_receive_period_in_days
    form_configurable :content, type: :text
    form_configurable :line_break_is_lf, type: :boolean
    form_configurable :mime_type
    form_configurable :mode, type: :array, values: ['Last event in', 'Merge events', 'Last X events']
    form_configurable :event_limit

    before_save :update_last_modified_at, if: :options_changed?

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
        errors.add(
          :base,
          "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working"
        )
      end

      event_limit =
        if value = options['event_limit'].presence
          begin
            Integer(value)
          rescue StandardError
            false
          end
        end

      if event_limit == false && date_limit.blank?
        errors.add(:base, "Event limit must be an integer that is less than 1001 or an integer plus a valid unit.")
      elsif event_limit && event_limit > 1000
        errors.add(:base, "For performance reasons, you cannot have an event limit greater than 1000.")
      end
    end

    def receive(incoming_events)
      return unless ['merge events', 'last event in'].include?(mode)

      memory['last_event'] ||= {}
      incoming_events.each do |event|
        memory['last_event'] =
          case mode
          when 'merge events'
            memory['last_event'].merge(event.payload)
          else
            event.payload
          end
      end
      update_last_modified_at
    end

    def receive_web_request(request)
      if valid_authentication?(request.params)
        if request.headers['If-None-Match'].presence&.include?(etag)
          [nil, 304, {}]
        else
          [liquified_content, 200, mime_type, response_headers]
        end
      else
        [unauthorized_content(request.format.to_s), 401]
      end
    end

    private

    def mode
      options['mode'].to_s.downcase
    end

    def unauthorized_content(format)
      if format =~ /json/
        { error: "Not Authorized" }
      else
        "Not Authorized"
      end
    end

    def valid_authentication?(params)
      interpolated['secret'] == params['secret']
    end

    def mime_type
      options['mime_type'].presence || 'text/html'
    end

    def liquified_content
      content = interpolated(data_for_liquid_template)['content']
      content.gsub!(/\r(?=\n)/, '') if boolify(options['line_break_is_lf'])
      content
    end

    def data_for_liquid_template
      case mode
      when 'last x events'
        events = received_events
        events = events.where('events.created_at > ?', date_limit) if date_limit
        events = events.limit count_limit
        events = events.to_a.map { |x| x.payload }
        { 'events' => events }
      else
        memory['last_event'] || {}
      end
    end

    public def etag
      memory['etag'] || '"0.000000000"'
    end

    def last_modified_at
      memory['last_modified_at']&.to_time || Time.at(0)
    end

    def last_modified_at=(time)
      memory['last_modified_at'] = time.iso8601(9)
      memory['etag'] = time.strftime('"%s.%9N"')
    end

    def update_last_modified_at
      self.last_modified_at = Time.now
    end

    def max_age
      options['expected_receive_period_in_days'].to_i * 86400
    end

    def response_headers
      {
        'Last-Modified' => last_modified_at.httpdate,
        'ETag' => etag,
        'Cache-Control' => "max-age=#{max_age}",
      }.update(interpolated['response_headers'].presence || {})
    end

    def count_limit
      [Integer(options['event_limit']), 1000].min
    rescue StandardError
      1000
    end

    def date_limit
      return nil unless options['event_limit'].to_s.include?(' ')

      value, unit = options['event_limit'].split(' ')
      value = begin
        Integer(value)
      rescue StandardError
        nil
      end
      return nil unless value

      unit = unit.to_s.downcase
      return nil unless DATE_UNITS.include?(unit)

      value.send(unit.to_sym).ago
    end
  end
end
