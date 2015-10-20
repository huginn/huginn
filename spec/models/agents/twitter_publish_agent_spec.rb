require 'rails_helper'

describe Agents::TwitterPublishAgent do
  before do
    @opts = {
      :username => "HuginnBot",
      :expected_update_period_in_days => "2",
      :consumer_key => "---",
      :consumer_secret => "---",
      :oauth_token => "---",
      :oauth_token_secret => "---",
      :message => "{{text}}"
    }

    @checker = Agents::TwitterPublishAgent.new(:name => "HuginnBot", :options => @opts)
    @checker.service = services(:generic)
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :text => 'Gonna rain..' }
    @event.save!

    @sent_messages = []
    stub.any_instance_of(Agents::TwitterPublishAgent).publish_tweet { |message|
      @sent_messages << message
      OpenStruct.new(:id => 454209588376502272)
    }
  end

  describe '#receive' do
    it 'should publish any payload it receives' do
      event1 = Event.new
      event1.agent = agents(:bob_rain_notifier_agent)
      event1.payload = { :text => 'Gonna rain..' }
      event1.save!

      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = { :text => 'More payload' }
      event2.save!

      Agents::TwitterPublishAgent.async_receive(@checker.id, [event1.id, event2.id])
      expect(@sent_messages.count).to eq(2)
      expect(@checker.events.count).to eq(2)
    end
  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      expect(@checker).not_to be_working # No events received
      Agents::TwitterPublishAgent.async_receive(@checker.id, [@event.id])
      expect(@checker.reload).to be_working # Just received events
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working # More time has passed than the expected receive period without any new events
    end
  end
end
