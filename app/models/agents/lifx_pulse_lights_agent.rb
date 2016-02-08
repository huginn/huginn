module Agents
  class LifxPulseLightsAgent < Agent
    include FormConfigurable
    
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      Orchestrates your LIFX lights (http://lifx.com/)
      
      To get your auth_token:
      
      - Log on and go to the Settings page of your [LIFX Account](https://cloud.lifx.com/settings)
      - Follow the instructions to "Generate New Token"
      - Copy the new token and use as the `auth_token` -OR- create a new credential called `lifx_auth_token`
      
      Read more about the [LIFX HTTP API](http://api.developer.lifx.com/) 
    MD
    
    form_configurable :auth_token
    form_configurable :light_selector
    form_configurable :color
    form_configurable :cycles
    form_configurable :persist, type: :boolean
    form_configurable :power_on, type: :boolean

    def validate_options
      errors.add(:base, "Provide a valid Auth token") unless auth_token.present? && client.get_lights
      errors.add(:base, "Light selector is required") unless options['light_selector'].present?
    end
    
    def default_options
      { 
        'auth_token' => '{% credential lifx_auth_token %}',
        'light_selector' => 'label:Bulb3',
        "color" => "#ff0000",
        "cycles" => 5,
        "persist" => false,
        "power_on" => true
      }
    end

    def working?
      (last_receive_at.present? && last_error_log_at.nil?) || (last_receive_at.present? && last_error_log_at.present? && last_receive_at > last_error_log_at)
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        client.pulse(options.slice(:color, :cycles, :persist, :power_on))
      end
    end
    
    private
    def auth_token
      interpolated[:auth_token].presence
    end
    
    def client
      @client ||= LifxClient.new(auth_token, interpolated[:light_selector])
    end
  end
end
