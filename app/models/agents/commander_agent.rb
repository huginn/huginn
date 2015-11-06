module Agents
  class CommanderAgent < Agent
    include AgentControllerConcern

    cannot_create_events!

    description <<-MD
      The Commander Agent is triggered by schedule or an incoming event, and commands other agents ("targets") to run, disable, configure, or enable themselves.

      # Action types

      Set `action` to one of the action types below:

      * `run`: Target Agents are run when this agent is triggered.

      * `disable`: Target Agents are disabled (if not) when this agent is triggered.

      * `enable`: Target Agents are enabled (if not) when this agent is triggered.

      * `configure`: Target Agents have their options updated with the contents of `configure_options`.

      Here's a tip: you can use Liquid templating to dynamically determine the action type.  For example:

      - To create a CommanderAgent that receives an event from a WeatherAgent every morning to kick an agent flow that is only useful in a nice weather, try this: `{% if conditions contains 'Sunny' or conditions contains 'Cloudy' %}` `run{% endif %}`

      - Likewise, if you have a scheduled agent flow specially crafted for rainy days, try this: `{% if conditions contains 'Rain' %}enable{% else %}disabled{% endif %}`

      - If you want to update a WeatherAgent based on a UserLocationAgent, you could use `'action': 'configure'` and set 'configure_options' to `{ 'location': '{{_location_.latlng}}' }`.

      # Targets

      Select Agents that you want to control from this CommanderAgent.
    MD

    def working?
      true
    end

    def check
      control!
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          control!
        end
      end
    end
  end
end
