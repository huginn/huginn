require 'rails_helper'

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
        'message' => "I saw '{{foo.bar.baz}}' from {{name}}"
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
      expect(@checker).to be_valid
    end

    it "should validate presence of message" do
      @checker.options['message'] = nil
      expect(@checker).not_to be_valid

      @checker.options['message'] = ''
      expect(@checker).not_to be_valid
    end

    it "should be valid without a message when 'keep_event' is set" do
      @checker.options['keep_event'] = 'true'
      @checker.options['message'] = ''
      expect(@checker).to be_valid
    end

    it "if present, 'keep_event' must equal true or false" do
      @checker.options['keep_event'] = 'true'
      expect(@checker).to be_valid

      @checker.options['keep_event'] = 'false'
      expect(@checker).to be_valid

      @checker.options['keep_event'] = ''
      expect(@checker).to be_valid

      @checker.options['keep_event'] = 'tralse'
      expect(@checker).not_to be_valid
    end

    it "validates that 'must_match' is a positive integer, not greater than the number of rules, if provided" do
      @checker.options['must_match'] = '1'
      expect(@checker).to be_valid

      @checker.options['must_match'] = '0'
      expect(@checker).not_to be_valid

      @checker.options['must_match'] = 'wrong'
      expect(@checker).not_to be_valid

      @checker.options['must_match'] = ''
      expect(@checker).to be_valid

      @checker.options.delete('must_match')
      expect(@checker).to be_valid

      @checker.options['must_match'] = '2'
      expect(@checker).not_to be_valid
      expect(@checker.errors[:base].first).to match(/equal to or less than the number of rules/)
    end

    it "should validate the three fields in each rule" do
      @checker.options['rules'] << { 'path' => "foo", 'type' => "fake", 'value' => "6" }
      expect(@checker).not_to be_valid
      @checker.options['rules'].last['type'] = "field>=value"
      expect(@checker).to be_valid
      @checker.options['rules'].last.delete('value')
      expect(@checker).not_to be_valid
    end
  end

  describe "#working?" do
    it "checks to see if the Agent has received any events in the last 'expected_receive_period_in_days' days" do
      @event.save!

      expect(@checker).not_to be_working # no events have ever been received
      Agents::TriggerAgent.async_receive(@checker.id, [@event.id])
      expect(@checker.reload).to be_working # Events received
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      expect(@checker.reload).not_to be_working # too much time has passed
    end
  end

  describe "#receive" do
    it "handles regex" do
      @event.payload['foo']['bar']['baz'] = "a222b"
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @event.payload['foo']['bar']['baz'] = "a2b"
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "handles array of regex" do
      @event.payload['foo']['bar']['baz'] = "a222b"
      @checker.options['rules'][0] = {
        'type' => "regex",
        'value' => ["a\\db", "a\\Wb"],
        'path' => "foo.bar.baz",
      }
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @event.payload['foo']['bar']['baz'] = "a2b"
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)

      @event.payload['foo']['bar']['baz'] = "a b"
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "handles negated regex" do
      @event.payload['foo']['bar']['baz'] = "a2b"
      @checker.options['rules'][0] = {
        'type' => "!regex",
        'value' => "a\\db",
        'path' => "foo.bar.baz",
      }

      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @event.payload['foo']['bar']['baz'] = "a22b"
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "handles array of negated regex" do
      @event.payload['foo']['bar']['baz'] = "a2b"
      @checker.options['rules'][0] = {
        'type' => "!regex",
        'value' => ["a\\db", "a2b"],
        'path' => "foo.bar.baz",
      }

      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @event.payload['foo']['bar']['baz'] = "a3b"
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "puts can extract values into the message based on paths" do
      @checker.receive([@event])
      expect(Event.last.payload['message']).to eq("I saw 'a2b' from Joe")
    end

    it "handles numerical comparisons" do
      @event.payload['foo']['bar']['baz'] = "5"
      @checker.options['rules'].first['value'] = 6
      @checker.options['rules'].first['type'] = "field<value"

      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)

      @checker.options['rules'].first['value'] = 3
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }
    end

    it "handles array of numerical comparisons" do
      @event.payload['foo']['bar']['baz'] = "5"
      @checker.options['rules'].first['value'] = [6, 3]
      @checker.options['rules'].first['type'] = "field<value"

      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)

      @checker.options['rules'].first['value'] = [4, 3]
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }
    end

    it "handles exact comparisons" do
      @event.payload['foo']['bar']['baz'] = "hello world"
      @checker.options['rules'].first['type'] = "field==value"

      @checker.options['rules'].first['value'] = "hello there"
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @checker.options['rules'].first['value'] = "hello world"
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "handles array of exact comparisons" do
      @event.payload['foo']['bar']['baz'] = "hello world"
      @checker.options['rules'].first['type'] = "field==value"

      @checker.options['rules'].first['value'] = ["hello there", "hello universe"]
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @checker.options['rules'].first['value'] = ["hello world", "hello universe"]
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "handles negated comparisons" do
      @event.payload['foo']['bar']['baz'] = "hello world"
      @checker.options['rules'].first['type'] = "field!=value"
      @checker.options['rules'].first['value'] = "hello world"

      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @checker.options['rules'].first['value'] = "hello there"

      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "handles array of negated comparisons" do
      @event.payload['foo']['bar']['baz'] = "hello world"
      @checker.options['rules'].first['type'] = "field!=value"
      @checker.options['rules'].first['value'] = ["hello world", "hello world"]

      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @checker.options['rules'].first['value'] = ["hello there", "hello world"]

      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)
    end

    it "does fine without dots in the path" do
      @event.payload = { 'hello' => "world" }
      @checker.options['rules'].first['type'] = "field==value"
      @checker.options['rules'].first['path'] = "hello"
      @checker.options['rules'].first['value'] = "world"
      expect {
        @checker.receive([@event])
      }.to change { Event.count }.by(1)

      @checker.options['rules'].first['path'] = "foo"
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }

      @checker.options['rules'].first['value'] = "hi"
      expect {
        @checker.receive([@event])
      }.not_to change { Event.count }
    end

    it "handles multiple events" do
      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = { 'foo' => { 'bar' => { 'baz' => "a2b" }}}

      event3 = Event.new
      event3.agent = agents(:bob_weather_agent)
      event3.payload = { 'foo' => { 'bar' => { 'baz' => "a222b" }}}

      expect {
        @checker.receive([@event, event2, event3])
      }.to change { Event.count }.by(2)
    end

    describe "with multiple rules" do
      before do
        @checker.options['rules'] << {
          'type' => "field>=value",
          'value' => "4",
          'path' => "foo.bing"
        }
      end

      it "handles ANDing rules together" do
        @event.payload['foo']["bing"] = "5"

        expect {
          @checker.receive([@event])
        }.to change { Event.count }.by(1)

        @event.payload['foo']["bing"] = "2"

        expect {
          @checker.receive([@event])
        }.not_to change { Event.count }
      end

      it "can accept a partial rule set match when 'must_match' is present and less than the total number of rules" do
        @checker.options['must_match'] = "1"

        @event.payload['foo']["bing"] = "5" # 5 > 4

        expect {
          @checker.receive([@event])
        }.to change { Event.count }.by(1)

        @event.payload['foo']["bing"] = "2" # 2 !> 4

        expect {
          @checker.receive([@event])
        }.to change { Event.count }         # but the first one matches


        @checker.options['must_match'] = "2"

        @event.payload['foo']["bing"] = "5" # 5 > 4

        expect {
          @checker.receive([@event])
        }.to change { Event.count }.by(1)

        @event.payload['foo']["bing"] = "2" # 2 !> 4

        expect {
          @checker.receive([@event])
        }.not_to change { Event.count }     # only 1 matches, we needed 2
      end
    end

    describe "when 'keep_event' is true" do
      before do
        @checker.options['keep_event'] = 'true'
        @event.payload['foo']['bar']['baz'] = "5"
        @checker.options['rules'].first['type'] = "field<value"
      end

      it "can re-emit the origin event" do
        @checker.options['rules'].first['value'] = 3
        @checker.options['message'] = ''
        @event.payload['message'] = 'hi there'

        expect {
          @checker.receive([@event])
        }.not_to change { Event.count }

        @checker.options['rules'].first['value'] = 6
        expect {
          @checker.receive([@event])
        }.to change { Event.count }.by(1)

        expect(@checker.most_recent_event.payload).to eq(@event.payload)
      end

      it "merges 'message' into the original event when present" do
        @checker.options['rules'].first['value'] = 6

        @checker.receive([@event])

        expect(@checker.most_recent_event.payload).to eq(@event.payload.merge(:message => "I saw '5' from Joe"))
      end
    end
  end
end
