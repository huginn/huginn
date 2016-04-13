require 'rails_helper'

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
    expect(@agent.last_web_request_at).to be_nil
    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    expect(@agent.reload.last_web_request_at).to be_within(2).of(Time.now)
    expect(response.body).to eq("success")
    expect(response).to be_success
  end

  it "should call receive_web_request" do
    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("text/html")
    expect(@agent.memory[:web_request_method]).to eq("post")
    expect(response.body).to eq("success")
    expect(response.headers['Content-Type']).to eq('text/plain; charset=utf-8')
    expect(response).to be_success

    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "not_my_secret", :no => "go"
    expect(@agent.reload.memory[:web_request_values]).not_to eq({ 'no' => "go" })
    expect(response.body).to eq("failure")
    expect(response).to be_missing
  end

  it "should accept gets" do
    get :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("text/html")
    expect(@agent.memory[:web_request_method]).to eq("get")
    expect(response.body).to eq("success")
    expect(response).to be_success
  end

  it "should pass through the received format" do
    get :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5", :format => :json
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("application/json")
    expect(@agent.memory[:web_request_method]).to eq("get")

    post :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5", :format => :xml
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("application/xml")
    expect(@agent.memory[:web_request_method]).to eq("post")

    put :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5", :format => :atom
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("application/atom+xml")
    expect(@agent.memory[:web_request_method]).to eq("put")
  end

  it "can accept a content-type to return" do
    @agent.memory['content_type'] = 'application/json'
    @agent.save!
    get :handle_request, :user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"
    expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
  end

  it "should fail on incorrect users" do
    post :handle_request, :user_id => users(:jane).to_param, :agent_id => @agent.id, :secret => "my_secret", :no => "go"
    expect(response).to be_missing
  end

  it "should fail on incorrect agents" do
    post :handle_request, :user_id => users(:bob).to_param, :agent_id => 454545, :secret => "my_secret", :no => "go"
    expect(response).to be_missing
  end

  describe "legacy update_location endpoint" do
    before do
      @agent = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), name: "something", options: { secret: "my_secret" })
      @agent.save!
    end

    it "should create events without requiring login" do
      post :update_location, user_id: users(:bob).to_param, secret: "my_secret", longitude: 123, latitude: 45, something: "else"
      expect(@agent.events.last.payload).to eq({ 'longitude' => "123", 'latitude' => "45", 'something' => "else" })
      expect(@agent.events.last.lat).to eq(45)
      expect(@agent.events.last.lng).to eq(123)
    end

    it "should only consider Agents::UserLocationAgents for the given user" do
      @jane_agent = Agent.build_for_type("Agents::UserLocationAgent", users(:jane), name: "something", options: { secret: "my_secret" })
      @jane_agent.save!

      post :update_location, user_id: users(:bob).to_param, secret: "my_secret", longitude: 123, latitude: 45, something: "else"
      expect(@agent.events.last.payload).to eq({ 'longitude' => "123", 'latitude' => "45", 'something' => "else" })
      expect(@jane_agent.events).to be_empty
    end

    it "should raise a 404 error when given an invalid user id" do
      post :update_location, user_id: "123", secret: "not_my_secret", longitude: 123, latitude: 45, something: "else"
      expect(response).to be_missing
    end

    it "should only look at agents with the given secret" do
      @agent2 = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), name: "something", options: { secret: "my_secret2" })
      @agent2.save!

      expect {
        post :update_location, user_id: users(:bob).to_param, secret: "my_secret2", longitude: 123, latitude: 45, something: "else"
        expect(@agent2.events.last.payload).to eq({ 'longitude' => "123", 'latitude' => "45", 'something' => "else" })
      }.not_to change { @agent.events.count }
    end
  end
end
