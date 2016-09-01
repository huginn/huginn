class AgentRegistry
  @@agents = []

  def self.types
    @@agents
  end

  def self.register_agent(klass)
    @@agents |= [klass]
  end
end
