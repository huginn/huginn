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
    
    form_configurable :light_selector, roles: :completable
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
        'light_selector' => 'all',
        "color" => "#ff0000",
        "cycles" => 5,
        "persist" => false,
        "power_on" => true
      }
    end
    
    def complete_light_selector
      selectors = client.get_selectors
      selectors.map do |selector| 
        { text: selector, id: selector }
      end
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        payload = interpolated(event)
        selector = payload["light_selector"]
        payload.slice!(:color, :cycles, :persist, :power_on)
        client(selector).pulse(payload)
      end
    end
    
    private
    def client(selector = "all")
      @client = LifxClient.new(service.token, selector)
    end
  end
end
