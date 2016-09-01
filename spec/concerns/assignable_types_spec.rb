require 'rails_helper'

describe Typeable do
  let(:non_agent_class) {
    Class.new(Object) do
      include ActiveModel::Validations
      include Typeable

      def type_changed?
        false
      end
    end
  }
  let(:agent_class) {
    Class.new(Agent) do
    end
  }

  it "disallows changes to type once a record has been saved" do
    source = agents(:bob_website_agent)
    source.type = "Agents::WeatherAgent"
    expect(source).to have(1).error_on(:type)
  end

  it "should know about available types" do
    expect(AgentRegistry.types.map(&:to_s)).to include("Agents::WeatherAgent", "Agents::WebsiteAgent")
    expect(AgentRegistry.types).not_to include(Agent)
  end
end
