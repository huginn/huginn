require 'spec_helper'

describe AgentHelper do

  it "should list agent types with html descriptions" do
    types = agent_types_collection_with_html_descriptions(users(:bob)) 
    agent_type = types.select { |t| t.first == "WeatherAgent" }
    agent_type.count.should eq(1)
    Base64.decode64(agent_type.first[2]['data-description']).should include('<p>')
  end

end