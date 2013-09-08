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
      Event.last.created_at.should be_within(1).of(Time.now)
    end
  end
end
