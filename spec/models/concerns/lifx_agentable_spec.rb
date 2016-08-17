require 'rails_helper'

describe LifxAgentable do
  class TestLifxAgent < Agent
    include LifxAgentable
    
    form_configurable :color
    form_configurable :cycles
    
    def default_options
      { 
        'light_selector' => 'all',
        "color" => "#ff0000"
      }
    end
    
    def receive(incoming_events)
      allowed_keys = ["color", "cycles"]
      respond_to_events(incoming_events, allowed_keys, :test_method)
    end
  end
  
  let(:agent_options) do
    { 
      "light_selector" => "label:Bulb3",
      "color" => "#ff0000"
    }
  end
    
  before do
    any_instance_of(LifxClient) do |client|
      stub(client).test_method { true }
    end
    
    stub(TestLifxAgent).valid_type? { true }
    
    @agent = TestLifxAgent.new(:name => "tester", :options => agent_options)
    @agent.user = users(:jane)
    @agent.service = services(:generic)
    @agent.save!
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
          mock(obj).test_method({
            "color" => "#ff0000"
          })
        end
        @agent.receive([Event.new]) 
      end
    end
  end
  
  context "with templated options" do
    let(:agent_options) do
      { 
        "light_selector" => "{{selector}}",
        "color" => "{{color}}"
      } 
    end
    
    describe "#receive" do
      it "accepts incoming event payloads" do
        any_instance_of(LifxClient) do |obj|
          mock(obj).test_method({
            "color" => "green"
          })
          
          mock(LifxClient).initialize(anything, "label:Bulb3")
        end
        @agent.receive([Event.new(payload: {
          selector: "label:Bulb3",
          color: "green",
          cycles: 2,
          persist: true,
          power_on: false
        })]) 
      end
      
      it "removes additional incoming payload information" do
        any_instance_of(LifxClient) do |obj|
          mock(obj).test_method({
            "color" => "#ff0000"
          })
        end
        @agent.receive([Event.new(payload: {
          "color" => "#ff0000",
          "extra" => "parameter"
        })]) 
      end
      
      it "accepts partial incoming payload information" do
        any_instance_of(LifxClient) do |obj|
          mock(obj).test_method({
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
