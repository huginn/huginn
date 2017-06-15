require 'rails_helper'

describe Agents::WeatherAgent do
  let(:agent) do
    Agents::WeatherAgent.create(
      name: 'weather',
      options: { 
        :location => 94103, 
        :lat => 37.779329, 
        :lng => -122.41915, 
        :api_key => 'test' 
      }
    ).tap do |agent|
      agent.user = users(:bob)  
      agent.save!
    end
  end
  
  it "creates a valid agent" do
    expect(agent).to be_valid
  end

  it "is valid with put-your-key-here or your-key" do
    agent.options['api_key'] = 'put-your-key-here'
    expect(agent).to be_valid
    expect(agent.working?).to be_falsey

    agent.options['api_key'] = 'your-key'
    expect(agent).to be_valid
    expect(agent.working?).to be_falsey
  end
  
  describe "#service" do
    it "doesn't have a Service object attached" do
      expect(agent.service).to be_nil
    end
  end
end
