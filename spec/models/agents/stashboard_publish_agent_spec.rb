require 'spec_helper'

describe Agents::StashboardPublishAgent do
  before do
    @opts = {
      :expected_update_period_in_days => "7",
      :service => "---",
      :status => "---",
      :message => "{{message}}",
      :addifnodef => false,
      :svcdesc => "{{svcdesc}}",
      :statlevel => "NORMAL",
      :statdesc => "{{statdesc}}",
      :statimage => "movie"
    }

    @checker = Agents::StashboardPublishAgent.new(:name => "StashboardBot", :options => @opts, :keep_events_for => 7)
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = {
      :service => "BobService",
      :status => "Maintenance",
      :message => "Gonna rain..",
      :addifnodef => "true",
      :svcdesc => "This service is new!",
      :statlevel => "WARNING",
      :statdesc => "This status is new!",
      :statimage => "traffic-cone"
    }
    @event.save!

    @sent_messages = []
    stub.any_instance_of(Agents::StashboardPublishAgent).publish_status { |svc, status, message_text|
      @sent_messages << [svc, status, message_text]
      OpenStruct.new(:id => 454209588376502272)
    }
  end

  describe '#receive' do
    it 'should publish any payload it receives' do
      event1 = Event.new
      event1.agent = agents(:bob_rain_notifier_agent)
      event1.payload = {
        :service => "BobService",
        :status => "Maintenance",
        :message => "Gonna rain..",
        :addifnodef => "true",
        :svcdesc => "This service is new!",
        :statlevel => "WARNING",
        :statdesc => "This status is new!",
        :statimage => "traffic-cone"
      }
      event1.save!

      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = {
        :service => "BobService",
        :status => "Up",
        :message => "Gonna rain..",
        :addifnodef => "true",
        :svcdesc => "This service is new!",
        :statlevel => "WARNING",
        :statdesc => "This status is new!",
        :statimage => "traffic-cone"
      }
      event2.save!

      event3 = Event.new
      event3.agent = agents(:bob_weather_agent)
      event3.payload = {
        :service => "JIRA",
        :status => "Down",
        :message => "Jira just went down!",
        #:statimage => "traffic-cone"
      }
      event3.save!

      Agents::StashboardPublishAgent.async_receive(@checker.id, [event1.id, event2.id, event3.id])
      @sent_messages.count.should eq(3)
      @checker.events.count.should eq(3)
    end
  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      @checker.should_not be_working # No events received
      Agents::StashboardPublishAgent.async_receive(@checker.id, [@event.id])
      @checker.reload.should be_working # Just received events
      seven_days_from_now = 7.days.from_now
      stub(Time).now { seven_days_from_now }
      @checker.reload.should_not be_working # More time has passed than the expected receive period without any new events
    end
  end
end
