module Agents
  class DeDuplicationAgent < Agent
    include FormConfigurable
    cannot_be_scheduled!

    description <<-MD
      The De-duplication Agent receives a stream of events and remits the event if it is not a duplicate.

      `property` the value that should be used to determine the uniqueness of the event (empty to use the whole payload)

      `lookback` amount of past Events to compare the value to (0 for unlimited)

      `expected_update_period_in_days` is used to determine if the Agent is working.
    MD

    event_description <<-MD
      The DeDuplicationAgent just reemits events it received.
    MD

    def default_options
      {
        'property' => '{{value}}',
        'lookback' => 100,
        'expected_update_period_in_days' => 1
      }
    end

    form_configurable :property
    form_configurable :lookback
    form_configurable :expected_update_period_in_days

    after_initialize :initialize_memory

    def initialize_memory
      memory['properties'] ||= []
    end

    def validate_options
      unless options['lookback'].present? && options['expected_update_period_in_days'].present?
        errors.add(:base, "The lookback and expected_update_period_in_days fields are all required.")
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

    def handle(opts, event = nil)
      property = get_hash(options['property'].blank? ? JSON.dump(event.payload) : opts['property'])
      if is_unique?(property)
        created_event = create_event :payload => event.payload

        log("Propagating new event as '#{property}' is a new unique property.", :inbound_event => event )
        update_memory(property, opts['lookback'].to_i)
      else
        log("Not propagating as incoming event is a duplicate.", :inbound_event => event )
      end
    end

    def get_hash(property)
      if property.to_s.length > 10
        Zlib::crc32(property).to_s
      else
        property
      end
    end

    def is_unique?(property)
      !memory['properties'].include?(property)
    end

    def update_memory(property, amount)
      if amount != 0 && memory['properties'].length == amount
        memory['properties'].shift
      end
      memory['properties'].push(property)
    end
  end
end
