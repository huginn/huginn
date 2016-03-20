require 'rails_helper'

describe Agents::LifxToggleLightsAgent do
  let(:agent_options) do
    { 
      "light_selector" => "label:Bulb3",
      "duration" => "10"
    }
  end
    
  before do
    @agent = Agents::LifxToggleLightsAgent.new(:name => "toggler", :options => agent_options)
    @agent.user = users(:jane)
    @agent.service = services(:generic)
    @agent.save!
  end
  
  describe "#receive" do
    it "makes an API request to LIFX" do
      any_instance_of(LifxClient) do |obj|
        mock(obj).toggle({
          "duration" => "10"
        })
      end
      @agent.receive([Event.new]) 
    end
  end
end
