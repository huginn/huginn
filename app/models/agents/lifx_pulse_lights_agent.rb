module Agents
  class LifxPulseLightsAgent < Agent
    include FormConfigurable
    include Oauthable
    valid_oauth_providers :'lifx'
    
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      Pulses your your [LIFX lights](http://lifx.com/) between their current color and a color you specify.
      
      To be able to use this Agent you need to authenticate with LIFX in the [Services](/services) section first.

      Read more about the [LIFX HTTP API](http://api.developer.lifx.com/) 
    MD
    
    form_configurable :light_selector
    form_configurable :color
    form_configurable :cycles
    form_configurable :persist, type: :boolean
    form_configurable :power_on, type: :boolean

    def validate_options
      errors.add(:base, "You need to authenticate with LIFX in the Services section") unless service.try(:token).present?
      errors.add(:base, "Light selector is required") unless options['light_selector'].present?
    end
    
    def default_options
      { 
        'light_selector' => 'label:Bulb3',
        "color" => "#ff0000",
        "cycles" => 5,
        "persist" => false,
        "power_on" => true
      }
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        client.pulse(options.slice(:color, :cycles, :persist, :power_on))
      end
    end
    
    private
    def client
      @client ||= LifxClient.new(service.token, interpolated[:light_selector])
    end
  end
end
