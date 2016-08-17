require 'rails_helper'

describe Agents::LifxPulseLightsAgent do
  let(:agent_options) do
    { 
      "light_selector" => "label:Bulb3",
      "color" => "#ff0000",
      "cycles" => 5,
      "persist" => false,
      "power_on" => true
    }
  end
    
  before do
    @agent = Agents::LifxPulseLightsAgent.new(:name => "pulser", :options => agent_options)
    @agent.user = users(:jane)
    @agent.service = services(:generic)
    @agent.save!
  end
  
  describe "#receive" do
    it "makes an API request to LIFX" do
      any_instance_of(LifxClient) do |obj|
        mock(obj).pulse({
          "color" => "#ff0000",
          "cycles" => 5,
          "persist" => false,
          "power_on" => true
        })
      end
      @agent.receive([Event.new]) 
    end
  end
end
