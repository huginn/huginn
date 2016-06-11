class AgentBuilder
  class << self
    def build_for_type(type, user, attributes = {})
      klass = Agent.types.detect{|agent_type| agent_type.name == type}

      raise NameError.new("#{type} is not an available agent") unless klass

      attributes.delete(:type)
      klass.new(attributes).tap do |instance|
        instance.user = user if instance.respond_to?(:user=)
      end
    end
  end
end
