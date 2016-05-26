class AgentBuilder
  class << self
    def build_for_type(type, user, attributes = {})
      begin
        klass = Agents.const_get(type)
      rescue NameError
        klass = Agent
      end

      klass = Agent unless klass <= Agent

      attributes.delete(:type)
      klass.new(attributes).tap do |instance|
        instance.user = user if instance.respond_to?(:user=)
      end
    end
  end
end
