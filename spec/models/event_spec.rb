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
    it "removes any Events whose expired_at date is non-null and in the past, updating Agent counter caches" do
      half_hour_event = agents(:jane_weather_agent).create_event :expires_at => 20.minutes.from_now
      one_hour_event = agents(:bob_weather_agent).create_event :expires_at => 1.hours.from_now
      two_hour_event = agents(:jane_weather_agent).create_event :expires_at => 2.hours.from_now
      three_hour_event = agents(:jane_weather_agent).create_event :expires_at => 3.hours.from_now
      non_expiring_event = agents(:bob_weather_agent).create_event({})

      initial_bob_count = agents(:bob_weather_agent).reload.events_count
      initial_jane_count = agents(:jane_weather_agent).reload.events_count

      current_time = Time.now
      stub(Time).now { current_time }

      Event.cleanup_expired!
      Event.find_by_id(half_hour_event.id).should_not be_nil
      Event.find_by_id(one_hour_event.id).should_not be_nil
      Event.find_by_id(two_hour_event.id).should_not be_nil
      Event.find_by_id(three_hour_event.id).should_not be_nil
      Event.find_by_id(non_expiring_event.id).should_not be_nil
      agents(:bob_weather_agent).reload.events_count.should == initial_bob_count
      agents(:jane_weather_agent).reload.events_count.should == initial_jane_count

      current_time = 119.minutes.from_now # move almost 2 hours into the future
      Event.cleanup_expired!
      Event.find_by_id(half_hour_event.id).should be_nil
      Event.find_by_id(one_hour_event.id).should be_nil
      Event.find_by_id(two_hour_event.id).should_not be_nil
      Event.find_by_id(three_hour_event.id).should_not be_nil
      Event.find_by_id(non_expiring_event.id).should_not be_nil
      agents(:bob_weather_agent).reload.events_count.should == initial_bob_count - 1
      agents(:jane_weather_agent).reload.events_count.should == initial_jane_count - 1

      current_time = 2.minutes.from_now # move 2 minutes further into the future
      Event.cleanup_expired!
      Event.find_by_id(two_hour_event.id).should be_nil
      Event.find_by_id(three_hour_event.id).should_not be_nil
      Event.find_by_id(non_expiring_event.id).should_not be_nil
      agents(:bob_weather_agent).reload.events_count.should == initial_bob_count - 1
      agents(:jane_weather_agent).reload.events_count.should == initial_jane_count - 2
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
