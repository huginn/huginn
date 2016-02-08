class LifxClient
  include HTTParty
  base_uri 'https://api.lifx.com/v1/lights'
  
  def initialize(auth_token, selector)
    @auth_token = auth_token
    @selector = selector
  end
    
  def get_lights
    response = self.class.get("/all", 
      headers: authorization_header,
    )
    if response.code == 404
      return false
    else
      response
    end
  end
  
  def toggle(options)
    self.class.post("/#{@selector}/toggle", 
      headers: authorization_header,
      body: options
    )
  end
  
  def pulse(options)
    self.class.post("/#{@selector}/effects/pulse", 
      headers: authorization_header,
      body: options
    )
  end
  
   def breathe(options)
    self.class.post("/#{@selector}/effects/breathe", 
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
