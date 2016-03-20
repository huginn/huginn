class LifxClient
  include HTTParty
  base_uri 'https://api.lifx.com/v1/lights'
  
  def initialize(auth_token, selector)
    @auth_token = auth_token
    @selector = selector
  end
    
  def get_selectors
    response = self.class.get("/all", 
      headers: authorization_header,
    )
    if response.code == 404
      return false
    else
      lights_json = JSON.parse(response.body)
      lights = []
      groups = []
      lights_json.each do |light| 
        lights << Light.new(light["id"], light["label"])
        groups << Group.new(light["group"]["id"], light["group"]["name"])
      end
      selectors = ["all"]
      selectors |= lights.map{|light| "label:#{light.label}"}
      selectors |= groups.map{|group| "group:#{group.label}"}
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
  
  class Light
    attr_reader :id, :label
    
    def initialize(id, label)
      @id = id
      @label = label
    end
  end
  
  class Group
    attr_reader :id, :label
    
    def initialize(id, label)
      @id = id
      @label = label
    end
  end
end
