require 'rails_helper'

describe Agents::LifxPulseLightsAgent do
  before(:each) do
    @valid_params = { 
        'auth_token' => 'VALID_TOKEN',
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
    @agent.save!
  end

  describe "validating" do
    before do
      expect(@agent).to be_valid
    end

    it "should require a auth_token" do
      @agent.options['auth_token'] = nil
      expect(@agent).not_to be_valid
      
      @agent.user.user_credentials.create :credential_name => 'lifx_auth_token', :credential_value => 'SOME_CREDENTIAL'
      expect(@agent).not_to be_valid
      
      @agent.options['auth_token'] = '{% credential lifx_auth_token %}'
      expect(@agent).to be_valid
    end
    
    it "verify the auth token by making a request" do
      any_instance_of(LifxClient) do |klass|
        stub(klass).get_lights { true }
      end
      expect(@agent).to be_valid
      
      any_instance_of(LifxClient) do |klass|
        stub(klass).get_lights { false }
      end
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

  it "should not be working until the first event was received" do
    expect(@agent).not_to be_working
    @agent.last_receive_at = Time.now
    expect(@agent).to be_working
  end

  it "should not be working when the last error occured after the last received event" do
    @agent.last_receive_at = Time.now - 1.minute
    @agent.last_error_log_at = Time.now
    expect(@agent).not_to be_working
  end

  it "should be working when the last received event occured after the last error" do
    @agent.last_receive_at = Time.now
    @agent.last_error_log_at = Time.now - 1.minute
    expect(@agent).to be_working
  end
end
