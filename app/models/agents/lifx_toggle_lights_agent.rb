module Agents
  class LifxToggleLightsAgent < Agent
    include LifxAgentable
    
    description <<-MD
      Turn off your [LIFX lights](http://lifx.com/) if any of them are on, or turn 
      them on if they are all off. All lights matched by the selector will 
      share the same power state after this action. Physically powered off 
      lights are ignored.
      
      To be able to use this Agent you need to authenticate with LIFX in the [Services](/services) section first.

      Read more about the [LIFX HTTP API](http://api.developer.lifx.com/) 
    MD
    
    form_configurable :duration
    
    def default_options
      { 
        'light_selector' => 'all',
        "duration" => ""
      }
    end
    
    def receive(incoming_events)
      allowed_keys = ["duration"]
      respond_to_events(incoming_events, allowed_keys, :toggle)
    end
  end
end
