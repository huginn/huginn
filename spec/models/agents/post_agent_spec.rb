require 'spec_helper'
require 'ostruct'

describe Agents::PostAgent do
  before do
    @valid_options = {
      'post_url' => "http://www.example.com",
      'expected_receive_period_in_days' => 1,
      'payload' => {
        'default' => 'value'
      }
    }
    @valid_params = {
      name: "somename",
      options: @valid_options
    }

    @checker = Agents::PostAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = {
      'somekey' => 'somevalue',
      'someotherkey' => {
        'somekey' => 'value'
      }
    }
    @requests = 0
    @sent_requests = Hash.new { |hash, method| hash[method] = [] }

    stub_request(:any, /:/).to_return { |request|
      method = request.method
      @requests += 1
      @sent_requests[method] << req = OpenStruct.new(uri: request.uri)
      case method
      when :get, :delete
        req.data = request.uri.query
      else
        case request.headers['Content-Type'][/\A[^;\s]+/]
        when 'application/x-www-form-urlencoded'
          req.data = request.body
        when 'application/json'
          req.data = ActiveSupport::JSON.decode(request.body)
        else
          raise "unexpected Content-Type: #{content_type}"
        end
      end
      { status: 200, body: "ok" }
    }
  end

  it_behaves_like WebRequestConcern

  describe "making requests" do
    it "can make requests of each type" do
      %w[get put post patch delete].each.with_index(1) do |verb, index|
        @checker.options['method'] = verb
        expect(@checker).to be_valid
        @checker.check
        expect(@requests).to eq(index)
        expect(@sent_requests[verb.to_sym].length).to eq(1)
      end
    end
  end

  describe "#receive" do
    it "can handle multiple events and merge the payloads with options['payload']" do
      event1 = Event.new
      event1.agent = agents(:bob_weather_agent)
      event1.payload = {
        'xyz' => 'value1',
        'message' => 'value2',
        'default' => 'value2'
      }

      expect {
        expect {
          @checker.receive([@event, event1])
        }.to change { @sent_requests[:post].length }.by(2)
      }.not_to change { @sent_requests[:get].length }

      expect(@sent_requests[:post][0].data).to eq(@event.payload.merge('default' => 'value').to_query)
      expect(@sent_requests[:post][1].data).to eq(event1.payload.to_query)
    end

    it "can make GET requests" do
      @checker.options['method'] = 'get'

      expect {
        expect {
          @checker.receive([@event])
        }.to change { @sent_requests[:get].length }.by(1)
      }.not_to change { @sent_requests[:post].length }

      expect(@sent_requests[:get][0].data).to eq(@event.payload.merge('default' => 'value').to_query)
    end

    it "can make a GET request merging params in post_url, payload and event" do
      @checker.options['method'] = 'get'
      @checker.options['post_url'] = "http://example.com/a/path?existing_param=existing_value"
      @event.payload = {
        "some_param" => "some_value",
        "another_param" => "another_value"
      }
      @checker.receive([@event])
      uri = @sent_requests[:get].first.uri
      # parameters are alphabetically sorted by Faraday
      expect(uri.request_uri).to eq("/a/path?another_param=another_value&default=value&existing_param=existing_value&some_param=some_value")
    end

    it "can skip merging the incoming event when no_merge is set, but it still interpolates" do
      @checker.options['no_merge'] = 'true'
      @checker.options['payload'] = {
        'key' => 'it said: {{ someotherkey.somekey }}'
      }
      @checker.receive([@event])
      expect(@sent_requests[:post].first.data).to eq({ 'key' => 'it said: value' }.to_query)
    end

    it "interpolates when receiving a payload" do
      @checker.options['post_url'] = "https://{{ domain }}/{{ variable }}?existing_param=existing_value"
      @event.payload = {
        'domain' => 'google.com',
        'variable' => 'a_variable'
      }
      @checker.receive([@event])
      uri = @sent_requests[:post].first.uri
      expect(uri.scheme).to eq('https')
      expect(uri.host).to eq('google.com')
      expect(uri.path).to eq('/a_variable')
      expect(uri.query).to eq("existing_param=existing_value")
    end
  end

  describe "#check" do
    it "sends options['payload'] as a POST request" do
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expect(@sent_requests[:post][0].data).to eq(@checker.options['payload'].to_query)
    end

    it "sends options['payload'] as JSON as a POST request" do
      @checker.options['content_type'] = 'json'
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expect(@sent_requests[:post][0].data).to eq(@checker.options['payload'])
    end

    it "sends options['payload'] as a GET request" do
      @checker.options['method'] = 'get'
      expect {
        expect {
          @checker.check
        }.to change { @sent_requests[:get].length }.by(1)
      }.not_to change { @sent_requests[:post].length }

      expect(@sent_requests[:get][0].data).to eq(@checker.options['payload'].to_query)
    end
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(@checker).not_to be_working
      Agents::PostAgent.async_receive @checker.id, [@event.id]
      expect(@checker.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of post_url" do
      @checker.options['post_url'] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options['expected_receive_period_in_days'] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate method as post, get, put, patch, or delete, defaulting to post" do
      @checker.options['method'] = ""
      expect(@checker.method).to eq("post")
      expect(@checker).to be_valid

      @checker.options['method'] = "POST"
      expect(@checker.method).to eq("post")
      expect(@checker).to be_valid

      @checker.options['method'] = "get"
      expect(@checker.method).to eq("get")
      expect(@checker).to be_valid

      @checker.options['method'] = "patch"
      expect(@checker.method).to eq("patch")
      expect(@checker).to be_valid

      @checker.options['method'] = "wut"
      expect(@checker.method).to eq("wut")
      expect(@checker).not_to be_valid
    end

    it "should validate that no_merge is 'true' or 'false', if present" do
      @checker.options['no_merge'] = ""
      expect(@checker).to be_valid

      @checker.options['no_merge'] = "true"
      expect(@checker).to be_valid

      @checker.options['no_merge'] = "false"
      expect(@checker).to be_valid

      @checker.options['no_merge'] = false
      expect(@checker).to be_valid

      @checker.options['no_merge'] = true
      expect(@checker).to be_valid

      @checker.options['no_merge'] = 'blarg'
      expect(@checker).not_to be_valid
    end

    it "should validate payload as a hash, if present" do
      @checker.options['payload'] = ""
      expect(@checker).to be_valid

      @checker.options['payload'] = "hello"
      expect(@checker).not_to be_valid

      @checker.options['payload'] = ["foo", "bar"]
      expect(@checker).not_to be_valid

      @checker.options['payload'] = { 'this' => 'that' }
      expect(@checker).to be_valid
    end

    it "requires headers to be a hash, if present" do
      @checker.options['headers'] = [1,2,3]
      expect(@checker).not_to be_valid

      @checker.options['headers'] = "hello world"
      expect(@checker).not_to be_valid

      @checker.options['headers'] = ""
      expect(@checker).to be_valid

      @checker.options['headers'] = {}
      expect(@checker).to be_valid

      @checker.options['headers'] = { "Authorization" => "foo bar" }
      expect(@checker).to be_valid
    end
  end
end
