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
        @checker.should be_valid
        @checker.check
        @requests.should == index
        @sent_requests[verb.to_sym].length.should == 1
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

      lambda {
        lambda {
          @checker.receive([@event, event1])
        }.should change { @sent_requests[:post].length }.by(2)
      }.should_not change { @sent_requests[:get].length }

      @sent_requests[:post][0].data.should == @event.payload.merge('default' => 'value').to_query
      @sent_requests[:post][1].data.should == event1.payload.to_query
    end

    it "can make GET requests" do
      @checker.options['method'] = 'get'

      lambda {
        lambda {
          @checker.receive([@event])
        }.should change { @sent_requests[:get].length }.by(1)
      }.should_not change { @sent_requests[:post].length }

      @sent_requests[:get][0].data.should == @event.payload.merge('default' => 'value').to_query
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
      uri.request_uri.should == "/a/path?another_param=another_value&default=value&existing_param=existing_value&some_param=some_value"
    end

    it "can skip merging the incoming event when no_merge is set, but it still interpolates" do
      @checker.options['no_merge'] = 'true'
      @checker.options['payload'] = {
        'key' => 'it said: {{ someotherkey.somekey }}'
      }
      @checker.receive([@event])
      @sent_requests[:post].first.data.should == { 'key' => 'it said: value' }.to_query
    end

    it "interpolates when receiving a payload" do
      @checker.options['post_url'] = "https://{{ domain }}/{{ variable }}?existing_param=existing_value"
      @event.payload = {
        'domain' => 'google.com',
        'variable' => 'a_variable'
      }
      @checker.receive([@event])
      uri = @sent_requests[:post].first.uri
      uri.scheme.should == 'https'
      uri.host.should == 'google.com'
      uri.path.should == '/a_variable'
      uri.query.should == "existing_param=existing_value"
    end
  end

  describe "#check" do
    it "sends options['payload'] as a POST request" do
      lambda {
        @checker.check
      }.should change { @sent_requests[:post].length }.by(1)

      @sent_requests[:post][0].data.should == @checker.options['payload'].to_query
    end

    it "sends options['payload'] as JSON as a POST request" do
      @checker.options['content_type'] = 'json'
      lambda {
        @checker.check
      }.should change { @sent_requests[:post].length }.by(1)

      @sent_requests[:post][0].data.should == @checker.options['payload']
    end

    it "sends options['payload'] as a GET request" do
      @checker.options['method'] = 'get'
      lambda {
        lambda {
          @checker.check
        }.should change { @sent_requests[:get].length }.by(1)
      }.should_not change { @sent_requests[:post].length }

      @sent_requests[:get][0].data.should == @checker.options['payload'].to_query
    end
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      @checker.should_not be_working
      Agents::PostAgent.async_receive @checker.id, [@event.id]
      @checker.reload.should be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      @checker.reload.should_not be_working
    end
  end

  describe "validation" do
    before do
      @checker.should be_valid
    end

    it "should validate presence of post_url" do
      @checker.options['post_url'] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options['expected_receive_period_in_days'] = ""
      @checker.should_not be_valid
    end

    it "should validate method as post, get, put, patch, or delete, defaulting to post" do
      @checker.options['method'] = ""
      @checker.method.should == "post"
      @checker.should be_valid

      @checker.options['method'] = "POST"
      @checker.method.should == "post"
      @checker.should be_valid

      @checker.options['method'] = "get"
      @checker.method.should == "get"
      @checker.should be_valid

      @checker.options['method'] = "patch"
      @checker.method.should == "patch"
      @checker.should be_valid

      @checker.options['method'] = "wut"
      @checker.method.should == "wut"
      @checker.should_not be_valid
    end

    it "should validate that no_merge is 'true' or 'false', if present" do
      @checker.options['no_merge'] = ""
      @checker.should be_valid

      @checker.options['no_merge'] = "true"
      @checker.should be_valid

      @checker.options['no_merge'] = "false"
      @checker.should be_valid

      @checker.options['no_merge'] = false
      @checker.should be_valid

      @checker.options['no_merge'] = true
      @checker.should be_valid

      @checker.options['no_merge'] = 'blarg'
      @checker.should_not be_valid
    end

    it "should validate payload as a hash, if present" do
      @checker.options['payload'] = ""
      @checker.should be_valid

      @checker.options['payload'] = "hello"
      @checker.should_not be_valid

      @checker.options['payload'] = ["foo", "bar"]
      @checker.should_not be_valid

      @checker.options['payload'] = { 'this' => 'that' }
      @checker.should be_valid
    end

    it "requires headers to be a hash, if present" do
      @checker.options['headers'] = [1,2,3]
      @checker.should_not be_valid

      @checker.options['headers'] = "hello world"
      @checker.should_not be_valid

      @checker.options['headers'] = ""
      @checker.should be_valid

      @checker.options['headers'] = {}
      @checker.should be_valid

      @checker.options['headers'] = { "Authorization" => "foo bar" }
      @checker.should be_valid
    end
  end
end
