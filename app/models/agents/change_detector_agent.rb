module Agents
  class ChangeDetectorAgent < Agent
    cannot_be_scheduled!

    description <<-MD
      The Change Detector Agent receives a stream of events and emits a new event when a property of the received event changes.

      `property` specifies the property to be watched.

      `expected_update_period_in_days` is used to determine if the Agent is working.

      The resulting event will be a copy of the received event.
    MD

    event_description <<-MD
    This will change based on the source event. If you were event from the ShellCommandAgent, your outbound event might look like:

      {
        'command' => 'pwd',
        'path' => '/home/Huginn',
        'exit_status' => '0',
        'errors' => '',
        'output' => '/home/Huginn'
      }
    MD

    def default_options
      {
          'property' => '{{output}}',
          'expected_update_period_in_days' => 1
      }
    end

    def validate_options
      unless options['property'].present? && options['expected_update_period_in_days'].present?
        errors.add(:base, "The property and expected_update_period_in_days fields are all required.")
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
      property = opts['property']
      if has_changed?(property)
        created_event = create_event :payload => event.payload

        log("Propagating new event as property has changed to #{property} from #{last_property}", :outbound_event => created_event, :inbound_event => event )
        update_memory(property)
      else
        log("Not propagating as incoming event has not changed from #{last_property}.", :inbound_event => event )
      end
    end

    def has_changed?(property)
      property != last_property
    end

    def last_property
      self.memory['last_property']
    end

    def update_memory(property)
      self.memory['last_property'] = property
    end
  end
end
