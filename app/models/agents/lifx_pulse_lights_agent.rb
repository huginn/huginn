module Agents
  class LifxPulseLightsAgent < Agent
    include LifxAgentable
    
    description <<-MD
      Performs a pulse effect by quickly flashing your [LIFX lights](http://lifx.com/) between the given colors. 
      
      To be able to use this Agent you need to authenticate with LIFX in the [Services](/services) section first.

      Read more about the [LIFX HTTP API](http://api.developer.lifx.com/) 
    MD
    
    form_configurable :color
    form_configurable :cycles
    form_configurable :persist, type: :boolean
    form_configurable :power_on, type: :boolean

    def default_options
      { 
        'light_selector' => 'all',
        "color" => "#ff0000",
        "cycles" => 5,
        "persist" => false,
        "power_on" => true
      }
    end
    
    def receive(incoming_events)
      allowed_keys = ["color", "cycles", "persist", "power_on"]
      respond_to_events(incoming_events, allowed_keys, :pulse)
    end
  end
end
