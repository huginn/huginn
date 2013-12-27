require 'spec_helper'

describe Agents::TriggerAgent do
  before do
    @valid_params = {
      'name' => "my trigger agent",
      'options' => {
        'expected_receive_period_in_days' => 2,
        'rules' => [{
                      'type' => "regex",
                      'value' => "a\\db",
                      'path' => "foo.bar.baz",
                    }],
        'message' => "I saw '<foo.bar.baz>' from <name>"
      }
    }

    @checker = Agents::TriggerAgent.new(@valid_params)
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_rain_notifier_agent)
    @event.payload = { 'foo' => { "bar" => { 'baz' => "a2b" }},
                       'name' => "Joe" }
  end

  describe "validation" do
    before do
      @checker.should be_valid
    end

    it "should validate presence of options" do
      @checker.options['message'] = nil
      @checker.should_not be_valid
    end

    it "should validate the three fields in each rule" do
      @checker.options['rules'] << { 'path' => "foo", 'type' => "fake", 'value' => "6" }
      @checker.should_not be_valid
      @checker.options['rules'].last['type'] = "field>=value"
      @checker.should be_valid
      @checker.options['rules'].last.delete('value')
      @checker.should_not be_valid
    end
  end

  describe "#working?" do
    it "checks to see if the Agent has received any events in the last 'expected_receive_period_in_days' days" do
      @event.save!

      @checker.should_not be_working # no events have ever been received
      Agents::TriggerAgent.async_receive(@checker.id, [@event.id])
      @checker.reload.should be_working # Events received
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      @checker.reload.should_not be_working # too much time has passed
    end
  end

  describe "#receive" do
    it "handles regex" do
      @event.payload['foo']['bar']['baz'] = "a222b"
      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }

      @event.payload['foo']['bar']['baz'] = "a2b"
      lambda {
        @checker.receive([@event])
      }.should change { Event.count }.by(1)
    end

    it "handles negated regex" do
      @event.payload['foo']['bar']['baz'] = "a2b"
      @checker.options['rules'][0] = {
        'type' => "!regex",
        'value' => "a\\db",
        'path' => "foo.bar.baz",
      }

      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }

      @event.payload['foo']['bar']['baz'] = "a22b"
      lambda {
        @checker.receive([@event])
      }.should change { Event.count }.by(1)
    end

    it "puts can extract values into the message based on paths" do
      @checker.receive([@event])
      Event.last.payload['message'].should == "I saw 'a2b' from Joe"
    end

    it "handles numerical comparisons" do
      @event.payload['foo']['bar']['baz'] = "5"
      @checker.options['rules'].first['value'] = 6
      @checker.options['rules'].first['type'] = "field<value"

      lambda {
        @checker.receive([@event])
      }.should change { Event.count }.by(1)

      @checker.options['rules'].first['value'] = 3
      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }
    end

    it "handles exact comparisons" do
      @event.payload['foo']['bar']['baz'] = "hello world"
      @checker.options['rules'].first['type'] = "field==value"

      @checker.options['rules'].first['value'] = "hello there"
      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }

      @checker.options['rules'].first['value'] = "hello world"
      lambda {
        @checker.receive([@event])
      }.should change { Event.count }.by(1)
    end

    it "handles negated comparisons" do
      @event.payload['foo']['bar']['baz'] = "hello world"
      @checker.options['rules'].first['type'] = "field!=value"
      @checker.options['rules'].first['value'] = "hello world"

      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }

      @checker.options['rules'].first['value'] = "hello there"

      lambda {
        @checker.receive([@event])
      }.should change { Event.count }.by(1)
    end

    it "does fine without dots in the path" do
      @event.payload = { 'hello' => "world" }
      @checker.options['rules'].first['type'] = "field==value"
      @checker.options['rules'].first['path'] = "hello"
      @checker.options['rules'].first['value'] = "world"
      lambda {
        @checker.receive([@event])
      }.should change { Event.count }.by(1)

      @checker.options['rules'].first['path'] = "foo"
      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }

      @checker.options['rules'].first['value'] = "hi"
      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }
    end

    it "handles multiple events" do
      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = { 'foo' => { 'bar' => { 'baz' => "a2b" }}}

      event3 = Event.new
      event3.agent = agents(:bob_weather_agent)
      event3.payload = { 'foo' => { 'bar' => { 'baz' => "a222b" }}}

      lambda {
        @checker.receive([@event, event2, event3])
      }.should change { Event.count }.by(2)
    end

    it "handles ANDing rules together" do
      @checker.options['rules'] << {
        'type' => "field>=value",
        'value' => "4",
        'path' => "foo.bing"
      }

      @event.payload['foo']["bing"] = "5"

      lambda {
        @checker.receive([@event])
      }.should change { Event.count }.by(1)

      @checker.options['rules'].last['value'] = 6
      lambda {
        @checker.receive([@event])
      }.should_not change { Event.count }
    end
  end
end