require 'rails_helper'

describe Agents::LifxPulseLightsAgent do
  before(:each) do
    @valid_params = { 
        'light_selector' => 'label:Bulb3',
        "color" => "#ff0000",
        "cycles" => 5,
        "persist" => false,
        "power_on" => true
      }
      
    any_instance_of(LifxClient) do |client|
      stub(client).get_lights { true }
    end

    @agent = Agents::LifxPulseLightsAgent.new(:name => "pulser", :options => @valid_params)
    @agent.user = users(:jane)
    @agent.service = services(:generic)
    @agent.save!
  end

  describe "validating" do
    before do
      expect(@agent).to be_valid
    end

    it "should require a LIFX authentication service" do
      @agent.service = nil
      expect(@agent).not_to be_valid
    end
    
    it "should require a light_selector" do
      @agent.options['light_selector'] = nil
      expect(@agent).not_to be_valid
    end
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

  it "uses the WorkingHelper to determine if the agent is working" do
    stub(@agent).received_event_without_error? { false }
    expect(@agent).not_to be_working
    stub(@agent).received_event_without_error? { true }
    expect(@agent).to be_working
  end
end
