# frozen_string_literal: true

module Agents
  class KeyValueStoreAgent < Agent
    can_control_other_agents!
    cannot_be_scheduled!
    cannot_create_events!

    description <<~MD
      The Key-Value Store Agent is a data storage that keeps an associative array in its memory.  It receives events to store values and provides the data to other agents as an object via Liquid Templating.

      Liquid templates specified in the `key` and `value` options are evaluated for each received event to be stored in the memory.

      The `variable` option specifies the name by which agents that use the storage refers to the data in Liquid templating.

      The `max_keys` option specifies up to how many keys to keep in the storage.  When the number of keys goes beyond this, the oldest key-value pair gets removed. (default: 100)

      ### Storing data

      For example, say your agent receives these incoming events:

          {
            "city": "Tokyo",
            "weather": "cloudy"
          }

          {
            "city": "Osaka",
            "weather": "sunny"
          }

      Then you could configure the agent with `{ "key": "{{ city }}", "value": "{{ weather }}" }` to get the following data stored:

          {
            "Tokyo": "cloudy",
            "Osaka": "sunny"
          }

      Here are some specifications:

      - Keys are always stringified as mandated by the JSON format.
      - Values are stringified by default.  Use the `as_object` filter to store non-string values.
      - If the value is evaluated to either `null` or empty (`""`, `[]`, `{}`) the key gets deleted.
      - In the `value` template, the existing value (if any) can be accessed via the variable `_value_`.
      - In the `key` and `value` templates, the whole event payload can be accessed via the variable `_event_`.

      ### Extracting data

      To allow other agents to use the data of a Key-Value Store Agent, designate the agent as a controller.
      You can do that by adding those agents to the "Controller targets" of the agent.

      The target agents can refer to the storage via the variable specified by the `variable` option value.  So, if the store agent in the above example had an option `"variable": "weather"`, they can say something like `{{ weather[city] | default: "unknown" }}` in their templates to get the weather of a city stored in the variable `city`.
    MD

    def validate_options
      options[:key].is_a?(String) or
        errors.add(:base, "key is required and must be a string.")

      options[:value] or
        errors.add(:base, "value is required.")

      /\A(?!\d)\w+\z/ === options[:variable] or
        errors.add(:base, "variable is required and must be valid as a variable name.")

      max_keys > 0 or
        errors.add(:base, "max_keys must be a positive number.")
    end

    def default_options
      {
        'key' => '{{ id }}',
        'value' => '{{ _event_ | as_object }}',
        'variable' => 'var',
      }
    end

    def working?
      !recent_error_logs?
    end

    def control_action
      'provide'
    end

    def max_keys
      if value = options[:max_keys].presence
        value.to_i
      else
        100
      end
    end

    def receive(incoming_events)
      max_keys = max_keys()

      incoming_events.each do |event|
        interpolate_with(event) do
          interpolation_context.stack do
            interpolation_context['_event_'] = event.payload

            key = interpolate_options(options)['key'].to_s

            storage = memory
            interpolation_context['_value_'] = storage.delete(key)

            value = interpolate_options(options)['value']

            if value.nil? || value.try(:empty?)
              storage.delete(key)
            else
              storage[key] = value
              storage.shift while storage.size > max_keys
            end

            update!(memory: storage)
          end
        end
      end
    end
  end
end
