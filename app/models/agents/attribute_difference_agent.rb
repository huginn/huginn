module Agents
  class AttributeDifferenceAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The Attribute Difference Agent receives events and emits a new event with
      the difference or change of a specific attribute in comparison to the previous
      event received.

      `path` specifies the JSON path of the attribute to be used from the event.

      `output` specifies the new attribute name that will be created on the original payload
      and it will contain the difference or change.

      `method` specifies if it should be...

      * `percentage_change` eg. Previous value was `160`, new value is `116`. Percentage change is `-27.5`
      * `decimal_difference` eg. Previous value was `5.5`, new value is `15.2`. Difference is `9.7`
      * `integer_difference` eg. Previous value was `50`, new value is `40`. Difference is `-10`

      `decimal_precision` defaults to `3`, but you can override this if you want.

      `expected_update_period_in_days` is used to determine if the Agent is working.

      The resulting event will be a copy of the received event with the difference
      or change added as an extra attribute. If you use the `percentage_change` the
      attribute will be formatted as such `{{attribute}}_change`, otherwise it will
      be `{{attribute}}_diff`.

      All configuration options will be liquid interpolated based on the incoming event.
    MD

    event_description <<-MD
      This will change based on the source event.
    MD

    def default_options
      {
        'path' => '.data.rate',
        'output' => 'rate_diff',
        'method' => 'integer_difference',
        'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      unless options['path'].present? && options['method'].present? && options['output'].present? && options['expected_update_period_in_days'].present?
        errors.add(:base, 'The attribute, method and expected_update_period_in_days fields are all required.')
      end
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        handle(interpolated(event), event)
      end
    end

    private

    def handle(opts, event)
      opts['decimal_precision'] ||= 3
      attribute_value = Utils.value_at(event.payload, opts['path'])
      attribute_value = attribute_value.nil? ? 0 : attribute_value
      payload = event.payload.deep_dup

      if opts['method'] == 'percentage_change'
        change = calculate_percentage_change(attribute_value, opts['decimal_precision'])
        payload[opts['output']] = change

      elsif opts['method'] == 'decimal_difference'
        difference = calculate_decimal_difference(attribute_value, opts['decimal_precision'])
        payload[opts['output']] = difference

      elsif opts['method'] == 'integer_difference'
        difference = calculate_integer_difference(attribute_value)
        payload[opts['output']] = difference
      end

      created_event = create_event(payload: payload)
      log('Propagating new event', outbound_event: created_event, inbound_event: event)
      update_memory(attribute_value)
    end

    def calculate_integer_difference(new_value)
      return 0 if last_value.nil?
      (new_value.to_i - last_value.to_i)
    end

    def calculate_decimal_difference(new_value, dec_pre)
      return 0.0 if last_value.nil?
      (new_value.to_f - last_value.to_f).round(dec_pre.to_i)
    end

    def calculate_percentage_change(new_value, dec_pre)
      return 0.0 if last_value.nil?
      (((new_value.to_f / last_value.to_f) * 100) - 100).round(dec_pre.to_i)
    end

    def last_value
      memory['last_value']
    end

    def update_memory(new_value)
      memory['last_value'] = new_value
    end
  end
end
