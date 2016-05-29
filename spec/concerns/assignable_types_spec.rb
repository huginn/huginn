require 'rails_helper'
require_relative '../../app/models/agents/weather_agent'
require_relative '../../app/models/agents/website_agent'

describe AssignableTypes do
  let(:non_agent_class) {
    Class.new(Object) do
      include ActiveModel::Validations
      include AssignableTypes

      def type_changed?
        false
      end
    end
  }
  let(:agent_class) {
    Class.new(Agent) do
    end
  }

  it "validates types" do
    source = agent_class.new(name: 'test') { |agent|
      agent.user = users(:bob)
    }
    expect(source).to have(0).errors_on(:type)
    source = non_agent_class.new
    expect(source).to have(1).error_on(:type)
  end

  it "disallows changes to type once a record has been saved" do
    source = agents(:bob_website_agent)
    source.type = "Agents::WeatherAgent"
    expect(source).to have(1).error_on(:type)
  end

  it "should know about available types" do
    Agents::WeatherAgent.new
    expect(Agent.types).to include(Agents::WeatherAgent, Agents::WebsiteAgent)
  end
end
