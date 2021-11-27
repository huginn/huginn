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
      :message => "{{text}}",
      :media_url => "{{media_url}}"
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
    @media_items = []
    stub.any_instance_of(Agents::TwitterPublishAgent).publish_tweet { |message, media_url|
      @sent_messages << message
      @media_items << media_url unless media_url.blank?
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

      event3 = Event.new
      event3.agent = agents(:bob_weather_agent)
      event3.payload = { :text => 'Payload with media', media_url: 'http://images.com/hello.png' }
      event3.save!

      Agents::TwitterPublishAgent.async_receive(@checker.id, [event1.id, event2.id, event3.id])
      expect(@sent_messages.count).to eq(3)
      expect(@checker.events.count).to eq(3)
      expect(@media_items.count).to eq(1)
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
