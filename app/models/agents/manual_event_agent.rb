module Agents
  class ManualEventAgent < Agent
    cannot_be_scheduled!
    cannot_receive_events!

    description <<~MD
      The Manual Event Agent is used to manually create Events for testing or other purposes.

      Connect this Agent to other Agents and create Events using the UI provided on this Agent's Summary page.

      You can set the default event payload via the "payload" option.
    MD

    event_description do
      "Events are editable in the UI.  The default value is this:\n\n    " +
        Utils.pretty_print(options["payload"].presence || {})
    end

    def default_options
      { "payload" => {} }
    end

    def handle_details_post(params)
      if params['payload']
        json = interpolate_options(JSON.parse(params['payload']))
        if json['payloads'] && (json.keys - ['payloads']).length > 0
          { success: false,
            error: "If you provide the 'payloads' key, please do not provide any other keys at the top level." }
        else
          [json['payloads'] || json].flatten.each do |payload|
            create_event(payload:)
          end
          { success: true }
        end
      else
        { success: false, error: "You must provide a JSON payload" }
      end
    end

    def working?
      true
    end

    def validate_options
    end
  end
end
