require 'lifx'

module Agents
  class LifxAgent < Agent
    cannot_be_scheduled!
    cannot_create_events!

    description <<-MD
      Orchestrates your LIF lights (http://lifx.com/)
      
      To get your auth_token:
      
      - Log on to your [LIFX Account](https://cloud.lifx.com/)
      - Click on your email address in the top right, and pick "Settings"
      - Follow the instructions to "Generate New Token"
      - Copy the new token and use as the `auth_token`
      
      ## Examples:
      This will pulse the bulb with label "Bulb3" red five times:
      
          {
            "auth_token": "YOUR_TOKEN_FROM_LIFX_HERE",
            "selector": "label:Bulb3",
            "action": "pulse_lights",
            "options": {
              "color": "#ff0000",
              "cycles": 5,
              "persist": false,
              "power_on": true
            }
          }
      
      This will turn all lights on to a faded blue over five seconds:
      
          {
            "auth_token": "YOUR_TOKEN_FROM_LIFX_HERE",
            "selector": "all",
            "action": "set_state",
            "options": {
              "power": "on",
              "color": "blue saturation:0.5",
              "brightness": 0.5,
              "duration": 5
            }
          }
      
      Read more about the [LIFX HTTP API](http://api.developer.lifx.com/) 
      
    MD

    def validate_options
      errors.add(:base, "auth_token is required") unless options['auth_token'].present?
      errors.add(:base, "selector is required") unless options['selector'].present?
    end
    
    def default_options
      { 
        'auth_token' => 'YOUR_TOKEN_FROM_LIFX_HERE',
        'selector' => 'label:Bulb3',
        "action" => "pulse_lights",
        "options" => {
          "color" => "#ff0000",
          "cycles" => 5,
          "persist" => false,
          "power_on" => true
        }
      }
    end

    def working?
      true
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        client.send(options[:action], options[:options])
      end
    end
    
    private
    def client
      @client ||= Lifx::Client.new(interpolated[:auth_token] || credential('hipchat_auth_token'), interpolated[:selector])
    end
  end
  
  module Lifx
    class Client
      include HTTParty
      base_uri 'https://api.lifx.com/v1/lights'
      
      def initialize(auth_token, selector)
        @auth_token = auth_token
        @selector = selector
      end
        
      def pulse_lights(options)
        self.class.post("/#{@selector}/effects/pulse", 
          headers: authorization_header,
          body: options
        )
      end
      
      def set_state(options)
        self.class.put("/#{@selector}/state", 
          headers: authorization_header,
          body: options
        )
      end
      
      def authorization_header
        {'Authorization' => "Bearer #{@auth_token}"}
      end
    end
  end
end
