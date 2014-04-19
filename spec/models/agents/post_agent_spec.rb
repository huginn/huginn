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

    @sent_messages = []
    stub.any_instance_of(Agents::PostAgent).post_data { |event| @sent_messages << event }
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
        @checker.receive([@event, event1])
      }.should change { @sent_messages.length }.by(2)

      @sent_messages[0].should == @event.payload.merge('default' => 'value')
      @sent_messages[1].should == event1.payload
    end
  end

  describe "#check" do
    it "sends options['payload']" do
      lambda {
        @checker.check
      }.should change { @sent_messages.length }.by(1)

      @sent_messages[0].should == @checker.options['payload']
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
      @checker.options[:post_url] = ""
      @checker.should_not be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options[:expected_receive_period_in_days] = ""
      @checker.should_not be_valid
    end

    it "should validate payload as a hash, if present" do
      @checker.options[:payload] = ""
      @checker.should be_valid

      @checker.options[:payload] = "hello"
      @checker.should_not be_valid

      @checker.options[:payload] = ["foo", "bar"]
      @checker.should_not be_valid

      @checker.options[:payload] = { 'this' => 'that' }
      @checker.should be_valid
    end
  end
end