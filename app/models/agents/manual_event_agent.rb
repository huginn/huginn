module Agents
  class ManualEventAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!

    description <<-MD
      The Manual Event Agent is used to manually create Events for testing or other purposes.

      Do not set options for this Agent.  Instead, connect it to other Agents and create Events
      using the UI provided on this Agent's Summary page.
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
