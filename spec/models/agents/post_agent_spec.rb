require 'spec_helper'

describe Agents::PostAgent do
  before do
    @valid_params = {
      :name => "somename",
      :options => {
        'post_url' => "http://www.example.com",
        'expected_receive_period_in_days' => 1,
        'payload' => {
          'default' => 'value'
        }
      }
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

    @sent_posts = []
    @sent_gets = []
    stub.any_instance_of(Agents::PostAgent).post_data { |data| @sent_posts << data }
    stub.any_instance_of(Agents::PostAgent).get_data { |data| @sent_gets << data }
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
        }.should change { @sent_posts.length }.by(2)
      }.should_not change { @sent_gets.length }

      @sent_posts[0].should == @event.payload.merge('default' => 'value')
      @sent_posts[1].should == event1.payload
    end

    it "can make GET requests" do
      @checker.options['method'] = 'get'

      lambda {
        lambda {
          @checker.receive([@event])
        }.should change { @sent_gets.length }.by(1)
      }.should_not change { @sent_posts.length }

      @sent_gets[0].should == @event.payload.merge('default' => 'value')
    end
  end

  describe "#check" do
    it "sends options['payload'] as a POST request" do
      lambda {
        @checker.check
      }.should change { @sent_posts.length }.by(1)

      @sent_posts[0].should == @checker.options['payload']
    end

    it "sends options['payload'] as a GET request" do
      @checker.options['method'] = 'get'
      lambda {
        lambda {
          @checker.check
        }.should change { @sent_gets.length }.by(1)
      }.should_not change { @sent_posts.length }

      @sent_gets[0].should == @checker.options['payload']
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

    it "should validate method as post or get, defaulting to post" do
      @checker.options['method'] = ""
      @checker.method.should == "post"
      @checker.should be_valid

      @checker.options['method'] = "POST"
      @checker.method.should == "post"
      @checker.should be_valid

      @checker.options['method'] = "get"
      @checker.method.should == "get"
      @checker.should be_valid

      @checker.options['method'] = "wut"
      @checker.method.should == "wut"
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

  describe "#generate_uri" do
    it "merges params with any in the post_url" do
      @checker.options['post_url'] = "http://example.com/a/path?existing_param=existing_value"
      uri = @checker.generate_uri("some_param" => "some_value", "another_param" => "another_value")
      uri.request_uri.should == "/a/path?existing_param=existing_value&some_param=some_value&another_param=another_value"
    end

    it "works fine with urls that do not have a query" do
      @checker.options['post_url'] = "http://example.com/a/path"
      uri = @checker.generate_uri("some_param" => "some_value", "another_param" => "another_value")
      uri.request_uri.should == "/a/path?some_param=some_value&another_param=another_value"
    end

    it "just returns the post_uri when no params are given" do
      @checker.options['post_url'] = "http://example.com/a/path?existing_param=existing_value"
      uri = @checker.generate_uri
      uri.request_uri.should == "/a/path?existing_param=existing_value"
    end
  end
end