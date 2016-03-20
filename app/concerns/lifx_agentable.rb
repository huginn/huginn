module LifxAgentable
  extend ActiveSupport::Concern
  
  included do
    cannot_be_scheduled!
    cannot_create_events!
    
    include FormConfigurable
    include Oauthable
    
    valid_oauth_providers :'lifx'
    
    description <<-MD
      To be able to use this Agent you need to authenticate with LIFX in the [Services](/services) section first.

      Read more about the [LIFX HTTP API](http://api.developer.lifx.com/) 
    MD
    
    form_configurable :light_selector, roles: :completable
  end
 
  def validate_options
    errors.add(:base, "You need to authenticate with LIFX in the Services section") unless service.try(:token).present?
    errors.add(:base, "Light selector is required") unless options['light_selector'].present?
  end
  
  def default_options
    { 
      'light_selector' => 'all'
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
  
  protected
  def prepare_options(payload, allowed_keys)
    payload.slice(*allowed_keys).delete_if{|_, v| v.try(:empty?) }
  end
  
  def client(selector = "all")
    @client = LifxClient.new(service.token, selector)
  end
  
  def respond_to_events(incoming_events, allowed_keys, lifx_method)
    incoming_events.each do |event|
      payload = interpolated(event)
      selector = payload["light_selector"]
      options = prepare_options(payload, allowed_keys)
      client(selector).send(lifx_method, options)
    end
  end
end