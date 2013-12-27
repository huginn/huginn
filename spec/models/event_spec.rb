require 'spec_helper'

describe Event do
  describe "#reemit" do
    it "creates a new event identical to itself" do
      events(:bob_website_agent_event).lat = 2
      events(:bob_website_agent_event).lng = 3
      events(:bob_website_agent_event).created_at = 2.weeks.ago
      lambda {
        events(:bob_website_agent_event).reemit!
      }.should change { Event.count }.by(1)
      Event.last.payload.should == events(:bob_website_agent_event).payload
      Event.last.agent.should == events(:bob_website_agent_event).agent
      Event.last.lat.should == 2
      Event.last.lng.should == 3
      Event.last.created_at.to_i.should be_within(2).of(Time.now.to_i)
    end
  end

  describe ".cleanup_expired!" do
    it "removes any Events whose expired_at date is non-null and in the past" do
      event = agents(:jane_weather_agent).create_event :expires_at => 2.hours.from_now

      current_time = Time.now
      stub(Time).now { current_time }

      Event.cleanup_expired!
      Event.find_by_id(event.id).should_not be_nil
      current_time = 119.minutes.from_now
      Event.cleanup_expired!
      Event.find_by_id(event.id).should_not be_nil
      current_time = 2.minutes.from_now
      Event.cleanup_expired!
      Event.find_by_id(event.id).should be_nil
    end

    it "doesn't touch Events with no expired_at" do
      event = Event.new
      event.agent = agents(:jane_weather_agent)
      event.expires_at = nil
      event.save!

      current_time = Time.now
      stub(Time).now { current_time }

      Event.cleanup_expired!
      Event.find_by_id(event.id).should_not be_nil
      current_time = 2.days.from_now
      Event.cleanup_expired!
      Event.find_by_id(event.id).should_not be_nil
    end
  end
end
