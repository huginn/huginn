module Agents
  class ReadFileAgent < Agent
    include FormConfigurable
    include FileHandling

    cannot_be_scheduled!
    consumes_file_pointer!

    def default_options
      {
        'data_key' => 'data'
      }
    end

    description do
      <<-MD
        The ReadFileAgent takes events from `FileHandling` agents, reads the file, and emits the contents as a string.

        `data_key` specifies the key of the emitted event which contains the file contents.

        #{receiving_file_handling_agent_description}
      MD
    end

    event_description <<-MD
      {
        "data" => '...'
      }
    MD

    form_configurable :data_key, type: :string

    def validate_options
      if options['data_key'].blank?
        errors.add(:base, "The 'data_key' options is required.")
      end
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        next unless io = get_io(event)
        create_event payload: { interpolated['data_key'] => io.read }
      end
    end
  end
end
