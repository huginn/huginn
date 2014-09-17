require 'spec_helper'

describe WebRequestsController do
  class Agents::WebRequestReceiverAgent < Agent
    cannot_receive_events!
    cannot_be_scheduled!

    def receive_web_request(params, method, format)
      if params.delete(:secret) == options[:secret]
        memory[:web_request_values] = params
        memory[:web_request_format] = format
        memory[:web_request_method] = method
        ["success", 200, memory['content_type']]
      else
        ["failure", 404]
      end
    end
  end

  before do
    stub(Agents::WebRequestReceiverAgent).valid_type?("Agents::WebRequestReceiverAgent") { true }
    @agent = Agents::WebRequestReceiverAgent.new(:name => "something", :options => { :secret => "my_secret" })
    @agent.user = users(:bob)
    @agent.save!
  end

  it "should not require login to receive a web request" do
    @agent.last_web_request_at.should be_nil
    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    @agent.reload.last_web_request_at.should be_within(2).of(Time.now)
    response.body.should == "success"
    response.should be_success
  end

  it "should call receive_web_request" do
    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    @agent.reload
    @agent.memory[:web_request_values].should == { 'key' => "value", 'another_key' => "5" }
    @agent.memory[:web_request_format].should == "text/html"
    @agent.memory[:web_request_method].should == "post"
    response.body.should == "success"
    response.headers['Content-Type'].should == 'text/plain; charset=utf-8'
    response.should be_success

    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "not_my_secret", :no => "go"
    @agent.reload.memory[:web_request_values].should_not == { 'no' => "go" }
    response.body.should == "failure"
    response.should be_missing
  end

  it "should accept gets" do
    get :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    @agent.reload
    @agent.memory[:web_request_values].should == { 'key' => "value", 'another_key' => "5" }
    @agent.memory[:web_request_format].should == "text/html"
    @agent.memory[:web_request_method].should == "get"
    response.body.should == "success"
    response.should be_success
  end

  it "should pass through the received format" do
    get :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5", :format => :json
    @agent.reload
    @agent.memory[:web_request_values].should == { 'key' => "value", 'another_key' => "5" }
    @agent.memory[:web_request_format].should == "application/json"
    @agent.memory[:web_request_method].should == "get"

    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5", :format => :xml
    @agent.reload
    @agent.memory[:web_request_values].should == { 'key' => "value", 'another_key' => "5" }
    @agent.memory[:web_request_format].should == "application/xml"
    @agent.memory[:web_request_method].should == "post"

    put :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5", :format => :atom
    @agent.reload
    @agent.memory[:web_request_values].should == { 'key' => "value", 'another_key' => "5" }
    @agent.memory[:web_request_format].should == "application/atom+xml"
    @agent.memory[:web_request_method].should == "put"
  end

  it "can accept a content-type to return" do
    @agent.memory['content_type'] = 'application/json'
    @agent.save!
    get :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    response.headers['Content-Type'].should == 'application/json; charset=utf-8'
  end

  it "should fail on incorrect users" do
    post :handle_request, :user_id => users(:jane).to_param, :agent_id => @agent.id, :secret => "my_secret", :no => "go"
    response.should be_missing
  end

  it "should fail on incorrect agents" do
    post :handle_request, :user_id => users(:bob).to_param, :agent_id => 454545, :secret => "my_secret", :no => "go"
    response.should be_missing
  end

  describe "legacy update_location endpoint" do
    before do
      @agent = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), name: "something", options: { secret: "my_secret" })
      @agent.save!
    end

    it "should create events without requiring login" do
      post :update_location, user_id: users(:bob).to_param, secret: "my_secret", longitude: 123, latitude: 45, something: "else"
      @agent.events.last.payload.should == { 'longitude' => "123", 'latitude' => "45", 'something' => "else" }
      @agent.events.last.lat.should == 45
      @agent.events.last.lng.should == 123
    end

    it "should only consider Agents::UserLocationAgents for the given user" do
      @jane_agent = Agent.build_for_type("Agents::UserLocationAgent", users(:jane), name: "something", options: { secret: "my_secret" })
      @jane_agent.save!

      post :update_location, user_id: users(:bob).to_param, secret: "my_secret", longitude: 123, latitude: 45, something: "else"
      @agent.events.last.payload.should == { 'longitude' => "123", 'latitude' => "45", 'something' => "else" }
      @jane_agent.events.should be_empty
    end

    it "should raise a 404 error when given an invalid user id" do
      post :update_location, user_id: "123", secret: "not_my_secret", longitude: 123, latitude: 45, something: "else"
      response.should be_missing
    end

    it "should only look at agents with the given secret" do
      @agent2 = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), name: "something", options: { secret: "my_secret2" })
      @agent2.save!

      lambda {
        post :update_location, user_id: users(:bob).to_param, secret: "my_secret2", longitude: 123, latitude: 45, something: "else"
        @agent2.events.last.payload.should == { 'longitude' => "123", 'latitude' => "45", 'something' => "else" }
      }.should_not change { @agent.events.count }
    end
  end
end
