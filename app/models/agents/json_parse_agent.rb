module Agents
  class JsonParseAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!

    description <<-MD
      The JSON Parse Agent parses a JSON string and emits the data in a new event

      `data` is the JSON to parse. Use [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) templating to specify the JSON string.

      `data_key` sets the key which contains the parsed JSON data in emitted events
    MD

    def default_options
      {
        'data' => '{{ data }}',
        'data_key' => 'data',
      }
    end

    event_description do
      "Events will looks like this:\n\n    %s" % Utils.pretty_print(interpolated['data_key'] => {parsed: 'object'})
    end

    form_configurable :data
    form_configurable :data_key

    def validate_options
      errors.add(:base, "data needs to be present") if options['data'].blank?
      errors.add(:base, "data_key needs to be present") if options['data_key'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        begin
          mo = interpolated(event)
          create_event payload: { mo['data_key'] => JSON.parse(mo['data']) }
        rescue JSON::JSONError => e
          error("Could not parse JSON: #{e.class} '#{e.message}'")
        end
      end
    end
  end
end
