module Agents
  class TriggerAgent < Agent
    cannot_be_scheduled!

    VALID_COMPARISON_TYPES = %w[regex !regex field<value field<=value field==value field!=value field>=value field>value]

    description <<-MD
      The Trigger Agent will watch for a specific value in an Event payload.

      The `rules` array contains hashes of `path`, `value`, and `type`.  The `path` value is a dotted path through a hash in [JSONPaths](http://goessner.net/articles/JsonPath/) syntax.

      The `type` can be one of #{VALID_COMPARISON_TYPES.map { |t| "`#{t}`" }.to_sentence} and compares with the `value`.  Note that regex patterns are matched case insensitively.  If you want case sensitive matching, prefix your pattern with `(?-i)`.

      The `value` can be a single value or an array of values. In the case of an array, if one or more values match then the rule matches.

      By default, all rules must match for the Agent to trigger. You can switch this so that only one rule must match by
      setting `must_match` to `1`.

      The resulting Event will have a payload message of `message`.  You can use liquid templating in the `message, have a look at the [Wiki](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) for details.

      Set `keep_event` to `true` if you'd like to re-emit the incoming event, optionally merged with 'message' when provided.

      Set `expected_receive_period_in_days` to the maximum amount of time that you'd expect to pass between Events being received by this Agent.
    MD

    event_description <<-MD
      Events look like this:

          { "message": "Your message" }
    MD

    def validate_options
      unless options['expected_receive_period_in_days'].present? && options['rules'].present? &&
             options['rules'].all? { |rule| rule['type'].present? && VALID_COMPARISON_TYPES.include?(rule['type']) && rule['value'].present? && rule['path'].present? }
        errors.add(:base, "expected_receive_period_in_days, message, and rules, with a type, value, and path for every rule, are required")
      end

      errors.add(:base, "message is required unless 'keep_event' is 'true'") unless options['message'].present? || keep_event?

      errors.add(:base, "keep_event, when present, must be 'true' or 'false'") unless options['keep_event'].blank? || %w[true false].include?(options['keep_event'])

      if options['must_match'].present?
        if options['must_match'].to_i < 1
          errors.add(:base, "If used, the 'must_match' option must be a positive integer")
        elsif options['must_match'].to_i > options['rules'].length
          errors.add(:base, "If used, the 'must_match' option must be equal to or less than the number of rules")
        end
      end
    end

    def default_options
      {
        'expected_receive_period_in_days' => "2",
        'keep_event' => 'false',
        'rules' => [{
                      'type' => "regex",
                      'value' => "foo\\d+bar",
                      'path' => "topkey.subkey.subkey.goal",
                    }],
        'message' => "Looks like your pattern matched in '{{value}}'!"
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|

        opts = interpolated(event)

        match_results = opts['rules'].map do |rule|
          value_at_path = Utils.value_at(event['payload'], rule['path'])
          rule_values = rule['value']
          rule_values = [rule_values] unless rule_values.is_a?(Array)

          rule_values.any? do |rule_value|
            case rule['type']
            when "regex"
              value_at_path.to_s =~ Regexp.new(rule_value, Regexp::IGNORECASE)
            when "!regex"
              value_at_path.to_s !~ Regexp.new(rule_value, Regexp::IGNORECASE)
            when "field>value"
              value_at_path.to_f > rule_value.to_f
            when "field>=value"
              value_at_path.to_f >= rule_value.to_f
            when "field<value"
              value_at_path.to_f < rule_value.to_f
            when "field<=value"
              value_at_path.to_f <= rule_value.to_f
            when "field==value"
              value_at_path.to_s == rule_value.to_s
            when "field!=value"
              value_at_path.to_s != rule_value.to_s
            else
              raise "Invalid type of #{rule['type']} in TriggerAgent##{id}"
            end
          end
        end

        if matches?(match_results)
          if keep_event?
            payload = event.payload.dup
            payload['message'] = opts['message'] if opts['message'].present?
          else
            payload = { 'message' => opts['message'] }
          end

          create_event :payload => payload
        end
      end
    end

    def matches?(matches)
      if options['must_match'].present?
        matches.select { |match| match }.length >= options['must_match'].to_i
      else
        matches.all?
      end
    end

    def keep_event?
      boolify(interpolated['keep_event'])
    end
  end
end
