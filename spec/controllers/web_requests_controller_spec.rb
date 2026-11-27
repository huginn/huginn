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
        [options.fetch('response', 'success'), (options[:status] || 200).to_i, memory['content_type'], memory['response_headers']]
      else
        ["failure", 404]
      end
    end
  end

  before do
    allow(Agents::WebRequestReceiverAgent).to receive(:valid_type?).with("Agents::WebRequestReceiverAgent") { true }
    @agent = Agents::WebRequestReceiverAgent.new(:name => "something", :options => { :secret => "my_secret" })
    @agent.user = users(:bob)
    @agent.save!
  end

  it "calls receive_web_request without login and records the request time" do
    expect(@agent.last_web_request_at).to be_nil
    post :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"}
    @agent.reload
    expect(@agent.last_web_request_at).to be_within(2).of(Time.now)
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("text/html")
    expect(@agent.memory[:web_request_method]).to eq("post")
    expect(response.body).to eq("success")
    expect(response.headers['Content-Type']).to eq('text/plain; charset=utf-8')
    expect(response).to be_successful

    post :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "not_my_secret", :no => "go"}
    expect(@agent.reload.memory[:web_request_values]).not_to eq({ 'no' => "go" })
    expect(response.body).to eq("failure")
    expect(response).to be_not_found
  end

  it "should accept gets" do
    get :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"}
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("text/html")
    expect(@agent.memory[:web_request_method]).to eq("get")
    expect(response.body).to eq("success")
    expect(response).to be_successful
  end

  it "should pass through the received format" do
    get :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"}, :format => :json
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("application/json")
    expect(@agent.memory[:web_request_method]).to eq("get")

    post :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"}, :format => :xml
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("application/xml")
    expect(@agent.memory[:web_request_method]).to eq("post")

    put :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"}, :format => :atom
    @agent.reload
    expect(@agent.memory[:web_request_values]).to eq({ 'key' => "value", 'another_key' => "5" })
    expect(@agent.memory[:web_request_format]).to eq("application/atom+xml")
    expect(@agent.memory[:web_request_method]).to eq("put")
  end

  it "can accept a content-type to return" do
    @agent.memory['content_type'] = 'application/json'
    @agent.save!
    get :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"}
    expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
  end

  it "sandboxes the response with a Content-Security-Policy header" do
    post :handle_request, params: { user_id: users(:bob).to_param, agent_id: @agent.id, secret: "my_secret" }
    expect(response.headers['Content-Security-Policy']).to eq("default-src 'none'; sandbox")
  end

  it "does not let custom response headers override the Content-Security-Policy header" do
    @agent.memory['response_headers'] = {"Content-Security-Policy" => "default-src *", "content-security-policy" => "default-src *"}
    @agent.save!
    post :handle_request, params: { user_id: users(:bob).to_param, agent_id: @agent.id, secret: "my_secret" }
    expect(response.headers['Content-Security-Policy']).to eq("default-src 'none'; sandbox")
  end

  it "can accept multiple custom response headers to return" do
    @agent.memory['response_headers'] = {"Access-Control-Allow-Origin" => "*", "X-My-Custom-Header" => "hello"}
    @agent.save!
    get :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret", :key => "value", :another_key => "5"}
    expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
    expect(response.headers['X-My-Custom-Header']).to eq('hello')
  end

  it 'should redirect correctly' do
    @agent.options['status'] = 302
    @agent.save
    post :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => @agent.id, :secret => "my_secret"}, format: :json
    expect(response).to redirect_to("http://test.host/users/#{users(:bob).to_param}/web_requests/#{@agent.id}/success")
  end

  describe 'Agent response permissions' do
    let(:request_params) { { user_id: @agent.user_id, agent_id: @agent.id, secret: 'my_secret' } }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ALLOW_UNRESTRICTED_AGENT_WEB_RESPONSES').and_return(nil)
    end

    it 'serves active content as text and enforces response safety headers' do
      @agent.memory['content_type'] = 'application/xhtml+xml'
      @agent.memory['response_headers'] = {
        'content-type' => 'text/html',
        'refresh' => '60',
        'referrer-policy' => 'unsafe-url',
      }
      @agent.save!

      get :handle_request, params: request_params

      expect(response.media_type).to eq('text/plain')
      expect(response.headers['Refresh']).to be_nil
      expect(response.headers['Referrer-Policy']).to eq('no-referrer')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    end

    it 'serves an RSS response as an attachment with its original media type' do
      @agent.memory['content_type'] = 'application/rss+xml'
      @agent.save!

      get :handle_request, params: request_params

      expect(response.media_type).to eq('application/rss+xml')
      expect(response.headers['Content-Disposition']).to eq('attachment')
    end

    it 'rejects an external redirect from a non-admin Agent even for an admin visitor' do
      sign_in users(:jane)
      @agent.options.merge!('status' => 302, 'response' => 'https://example.test/')
      @agent.save!

      get :handle_request, params: request_params

      expect(response).to have_http_status(:forbidden)
      expect(response.headers['Location']).to be_nil
    end

    it 'applies the same policy to a custom Location header' do
      @agent.options['status'] = 303
      @agent.memory['response_headers'] = { 'location' => 'https://example.test/' }
      @agent.save!

      get :handle_request, params: request_params

      expect(response).to have_http_status(:forbidden)
      expect(response.headers['Location']).to be_nil
    end

    it 'keeps a same-origin Location header' do
      @agent.options['status'] = 303
      @agent.memory['response_headers'] = { 'Location' => '/result' }
      @agent.save!

      get :handle_request, params: request_params

      expect(response).to have_http_status(:see_other)
      expect(response.headers['Location']).to eq('http://test.host/result')
    end

    it 'allows HTML and external redirects from an admin-owned Agent without login' do
      @agent.user = users(:jane)
      @agent.memory['content_type'] = 'text/html'
      @agent.memory['response_headers'] = { 'Refresh' => '60' }
      @agent.save!

      get :handle_request, params: request_params

      expect(response.media_type).to eq('text/html')
      expect(response.headers['Refresh']).to eq('60')
      expect(response.headers['Content-Security-Policy']).to eq('sandbox allow-scripts allow-forms allow-popups')

      @agent.options.merge!('status' => 302, 'response' => 'https://example.test/')
      @agent.save!

      get :handle_request, params: request_params

      expect(response).to redirect_to('https://example.test/')
      expect(response.headers['Referrer-Policy']).to eq('no-referrer')
    end

    it 'allows HTML for a non-admin owner when unrestricted responses are enabled' do
      allow(ENV).to receive(:[]).with('ALLOW_UNRESTRICTED_AGENT_WEB_RESPONSES').and_return('true')
      @agent.memory['content_type'] = 'text/html'
      @agent.save!

      get :handle_request, params: request_params

      expect(response.media_type).to eq('text/html')
      expect(response.headers['Referrer-Policy']).to eq('no-referrer')
    end
  end

  it "should fail on incorrect users" do
    post :handle_request, params: {:user_id => users(:jane).to_param, :agent_id => @agent.id, :secret => "my_secret", :no => "go"}
    expect(response).to be_not_found
  end

  it "should fail on incorrect agents" do
    post :handle_request, params: {:user_id => users(:bob).to_param, :agent_id => 454545, :secret => "my_secret", :no => "go"}
    expect(response).to be_not_found
  end

  it "responds to CORS preflight OPTIONS without requiring a matching secret" do
    expect {
      process :handle_request_options, method: :options, params: { user_id: users(:bob).to_param, agent_id: @agent.id, secret: "wrong_secret" }
    }.not_to change { @agent.reload.last_web_request_at }
    expect(response).to be_successful
    expect(response.body).to eq("OK")
    expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
    expect(response.headers['Access-Control-Allow-Methods']).to eq('POST, PUT, GET, DELETE, OPTIONS')
  end

  describe "legacy update_location endpoint" do
    before do
      @agent = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), name: "something", options: { secret: "my_secret" })
      @agent.save!
    end

    it "should create events without requiring login" do
      post :update_location, params: {user_id: users(:bob).to_param, secret: "my_secret", longitude: 123, latitude: 45, something: "else"}
      expect(@agent.events.last.payload).to eq({ 'longitude' => "123", 'latitude' => "45", 'something' => "else" })
      expect(@agent.events.last.lat).to eq(45)
      expect(@agent.events.last.lng).to eq(123)
    end

    it "should only consider Agents::UserLocationAgents for the given user" do
      @jane_agent = Agent.build_for_type("Agents::UserLocationAgent", users(:jane), name: "something", options: { secret: "my_secret" })
      @jane_agent.save!

      post :update_location, params: {user_id: users(:bob).to_param, secret: "my_secret", longitude: 123, latitude: 45, something: "else"}
      expect(@agent.events.last.payload).to eq({ 'longitude' => "123", 'latitude' => "45", 'something' => "else" })
      expect(@jane_agent.events).to be_empty
    end

    it "should raise a 404 error when given an invalid user id" do
      post :update_location, params: {user_id: "123", secret: "not_my_secret", longitude: 123, latitude: 45, something: "else"}
      expect(response).to be_not_found
    end

    it "should only look at agents with the given secret" do
      @agent2 = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), name: "something", options: { secret: "my_secret2" })
      @agent2.save!

      expect {
        post :update_location, params: {user_id: users(:bob).to_param, secret: "my_secret2", longitude: 123, latitude: 45, something: "else"}
        expect(@agent2.events.last.payload).to eq({ 'longitude' => "123", 'latitude' => "45", 'something' => "else" })
      }.not_to change { @agent.events.count }
    end
  end
end
