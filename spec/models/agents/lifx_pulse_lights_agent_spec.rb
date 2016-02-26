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
    
    any_instance_of(LifxClient) do |client|
      stub(client).get_lights { true }
    end
  end
  
  context "with untemplated options" do
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
  end
  
  context "with templated options" do
    let(:agent_options) do
      { 
        "light_selector" => "label:Bulb3",
        "color" => "{{color}}",
        "cycles" => "{{cycles}}",
        "persist" => "{{persist}}",
        "power_on" => "{{power_on}}"
      } 
    end
    
    describe "#receive" do
      it "accepts incoming event payloads" do
        any_instance_of(LifxClient) do |obj|
          mock(obj).pulse({
            "color" => "green",
            "cycles" => "2",
            "persist" => "true",
            "power_on" => "false"
          })
        end
        @agent.receive([Event.new(payload: {
          color: "green",
          cycles: 2,
          persist: true,
          power_on: false
        })]) 
      end
      
      it "removes additional incoming payload information" do
        any_instance_of(LifxClient) do |obj|
          mock(obj).pulse({
            "color" => "#ff0000",
            "cycles" => "5",
            "persist" => "false",
            "power_on" => "true"
          })
        end
        @agent.receive([Event.new(payload: {
          "color" => "#ff0000",
          "cycles" => 5,
          "persist" => false,
          "power_on" => true,
          extra: "parameter"
        })]) 
      end
      
      it "accepts partial incoming payload information" do
        any_instance_of(LifxClient) do |obj|
          mock(obj).pulse({
            "color" => "green"
          })
        end
        @agent.receive([Event.new(payload: {
          color: "green"
        })]) 
      end
    end
  end
  
  it "uses the WorkingHelper to determine if the agent is working" do
    stub(@agent).received_event_without_error? { false }
    expect(@agent).not_to be_working
    stub(@agent).received_event_without_error? { true }
    expect(@agent).to be_working
  end
end
