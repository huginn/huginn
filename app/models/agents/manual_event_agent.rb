module Agents
  class ManualEventAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!

    description <<-MD
      Use this Agent to manually create Events for testing or other purposes.
    MD

    event_description "User determined"

    def default_options
      { "no options" => "are needed" }
    end

    def handle_details_post(params)
      if params['payload']
        create_event(:payload => params['payload'])
        { :success => true }
      else
        { :success => false, :error => "You must provide a JSON payload" }
      end
    end

    def working?
      true
    end

    def validate_options
    end
  end
end