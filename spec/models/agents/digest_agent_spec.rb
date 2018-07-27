require "rails_helper"

describe Agents::DigestAgent do
  before do
    @checker = Agents::DigestAgent.new(:name => "something", :options => { :expected_receive_period_in_days => "2", :retained_events => "0", :message => "{{ events | map:'data' | join:';' }}" })
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#working?" do
    it "checks to see if the Agent has received any events in the last 'expected_receive_period_in_days' days" do
      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = { :data => "event" }
      event.save!

      expect(@checker).not_to be_working # no events have ever been received
      @checker.options[:expected_receive_period_in_days] = 2
      @checker.save!
      Agents::DigestAgent.async_receive @checker.id, [event.id]
      expect(@checker.reload).to be_working # Events received
      three_days_from_now = 3.days.from_now
      stub(Time).now { three_days_from_now }
      expect(@checker).not_to be_working # too much time has passed
    end
  end
  
  describe "validation" do
    before do
      expect(@checker).to be_valid
    end
    
    it "should validate retained_events" do
      @checker.options[:retained_events] = ""
      expect(@checker).to be_valid
      @checker.options[:retained_events] = "0"
      expect(@checker).to be_valid
      @checker.options[:retained_events] = "10"
      expect(@checker).to be_valid
      @checker.options[:retained_events] = "10000"
      expect(@checker).not_to be_valid
      @checker.options[:retained_events] = "-1"
      expect(@checker).not_to be_valid
    end

  end

  describe "#receive" do
    
    describe "and retained_events is 0" do
      
      before { @checker.options['retained_events'] = 0 }
      
      it "retained_events any payloads it receives" do
        event1 = Event.new
        event1.agent = agents(:bob_rain_notifier_agent)
        event1.payload = { :data => "event1" }
        event1.save!

        event2 = Event.new
        event2.agent = agents(:bob_weather_agent)
        event2.payload = { :data => "event2" }
        event2.save!  
    
        @checker.receive([event1])
        @checker.receive([event2])
        expect(@checker.memory["queue"]).to eq([event1.id, event2.id])
      end
    end
      
    describe "but retained_events is 1" do
      
      before { @checker.options['retained_events'] = 1 }
      
      it "retained_eventss only 1 event at a time" do
        event1 = Event.new
        event1.agent = agents(:bob_rain_notifier_agent)
        event1.payload = { :data => "event1" }
        event1.save!

        event2 = Event.new
        event2.agent = agents(:bob_weather_agent)
        event2.payload = { :data => "event2" }
        event2.save!  
    
        @checker.receive([event1])
        @checker.receive([event2])
        expect(@checker.memory['queue']).to eq([event2.id])
      end
    end
      
  end

  describe "#check" do
    
    describe "and retained_events is 0" do
      
      before { @checker.options['retained_events'] = 0 }
      
      it "should emit a event" do
        expect { Agents::DigestAgent.async_check(@checker.id) }.not_to change { Event.count }

        event1 = Event.new
        event1.agent = agents(:bob_rain_notifier_agent)
        event1.payload = { :data => "event" }
        event1.save!

        event2 = Event.new
        event2.agent = agents(:bob_weather_agent)
        event2.payload = { :data => "event" }
        event2.save!

        @checker.receive([event1])
        @checker.receive([event2])
        @checker.sources << agents(:bob_rain_notifier_agent) << agents(:bob_weather_agent)
        @checker.save!

        expect { @checker.check }.to change { Event.count }.by(1)
        expect(@checker.most_recent_event.payload["events"]).to eq([event1.payload, event2.payload])
        expect(@checker.most_recent_event.payload["message"]).to eq("event;event")
        expect(@checker.memory['queue']).to be_empty
      end
    end
    
    describe "but retained_events is 1" do
      
      before { @checker.options['retained_events'] = 1 }
      
      it "should emit a event" do
        expect { Agents::DigestAgent.async_check(@checker.id) }.not_to change { Event.count }

        event1 = Event.new
        event1.agent = agents(:bob_rain_notifier_agent)
        event1.payload = { :data => "event" }
        event1.save!

        event2 = Event.new
        event2.agent = agents(:bob_weather_agent)
        event2.payload = { :data => "event" }
        event2.save!

        @checker.receive([event1])
        @checker.receive([event2])
        @checker.sources << agents(:bob_rain_notifier_agent) << agents(:bob_weather_agent)
        @checker.save!

        expect { @checker.check }.to change { Event.count }.by(1)
        expect(@checker.most_recent_event.payload["events"]).to eq([event2.payload])
        expect(@checker.most_recent_event.payload["message"]).to eq("event")
        expect(@checker.memory['queue'].length).to eq(1)
      end
    end
  end
end
