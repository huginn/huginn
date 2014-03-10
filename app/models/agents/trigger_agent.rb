module Agents
  class TriggerAgent < Agent
    cannot_be_scheduled!

    VALID_COMPARISON_TYPES = %w[regex !regex field<value field<=value field==value field!=value field>=value field>value]

    description <<-MD
      Use a TriggerAgent to watch for a specific value in an Event payload.

      The `rules` array contains hashes of `path`, `value`, and `type`.  The `path` value is a dotted path through a hash in [JSONPaths](http://goessner.net/articles/JsonPath/) syntax.

      The `type` can be one of #{VALID_COMPARISON_TYPES.map { |t| "`#{t}`" }.to_sentence} and compares with the `value`.

      All rules must match for the Agent to match.  The resulting Event will have a payload message of `message`.  You can include extractions in the message, for example: `I saw a bar of: <foo.bar>`

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    event_description <<-MD
      Events look like this:

          { "message": "Your message" }
    MD

    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['message'].present? && options['rules'].present? &&
          options['rules'].all? { |rule| rule['type'].present? && VALID_COMPARISON_TYPES.include?(rule['type']) && rule['value'].present? && rule['path'].present? }
        errors.add(:base, "expected_receive_period_in_days, message, and rules, with a type, value, and path for every rule, are required")
      end
    end

    def default_options
      {
        'expected_receive_period_in_days' => "2",
        'rules' => [{
                      'type' => "regex",
                      'value' => "foo\\d+bar",
                      'path' => "topkey.subkey.subkey.goal",
                    }],
        'message' => "Looks like your pattern matched in '<value>'!"
      }
    end

    def working?
      last_receive_at && last_receive_at > options['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        match = options['rules'].all? do |rule|
          value_at_path = Utils.value_at(event['payload'], rule['path'])
          case rule['type']
            when "regex"
              value_at_path.to_s =~ Regexp.new(rule['value'], Regexp::IGNORECASE)
            when "!regex"
              value_at_path.to_s !~ Regexp.new(rule['value'], Regexp::IGNORECASE)
            when "field>value"
              value_at_path.to_f > rule['value'].to_f
            when "field>=value"
              value_at_path.to_f >= rule['value'].to_f
            when "field<value"
              value_at_path.to_f < rule['value'].to_f
            when "field<=value"
              value_at_path.to_f <= rule['value'].to_f
            when "field==value"
              value_at_path.to_s == rule['value'].to_s
            when "field!=value"
              value_at_path.to_s != rule['value'].to_s
            else
              raise "Invalid type of #{rule['type']} in TriggerAgent##{id}"
          end
        end

        if match
          create_event :payload => { 'message' => make_message(event[:payload]) } # Maybe this should include the
                                                                                  # original event as well?
        end
      end
    end
  end
end