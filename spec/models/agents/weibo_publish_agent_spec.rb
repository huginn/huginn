# encoding: utf-8
require 'rails_helper'

describe Agents::WeiboPublishAgent do
  before do
    @opts = {
      :uid => "1234567",
      :expected_update_period_in_days => "2",
      :app_key => "---",
      :app_secret => "---",
      :access_token => "---",
      :message_path => "text",
      :pic_path => "pic"
    }

    @checker = Agents::WeiboPublishAgent.new(:name => "Weibo Publisher", :options => @opts)
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :text => 'Gonna rain..' }
    @event.save!

    @sent_messages = []
    @sent_pictures = []
    stub.any_instance_of(Agents::WeiboPublishAgent).publish_tweet { |message| @sent_messages << message}
    stub.any_instance_of(Agents::WeiboPublishAgent).publish_tweet_with_pic { |message, picture| @sent_pictures << picture}
    stub.any_instance_of(Agents::WeiboPublishAgent).sleep
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

      Agents::WeiboPublishAgent.async_receive(@checker.id, [event1.id, event2.id])
      expect(@sent_messages.count).to eq(2)
      expect(@checker.events.count).to eq(2)
    end
  end

  describe '#receive a tweet' do
    it 'should publish a tweet after expanding any t.co urls' do
      event = Event.new
      event.agent = agents(:bob_twitter_user_agent)
      event.payload = JSON.parse(File.read(Rails.root.join("spec/data_fixtures/one_tweet.json")))
      event.save!

      Agents::WeiboPublishAgent.async_receive(@checker.id, [event.id])
      expect(@sent_messages.count).to eq(1)
      expect(@sent_pictures.count).to eq(0)
      expect(@checker.events.count).to eq(1)
      expect(@sent_messages.first.include?("t.co")).not_to be_truthy
    end
  end

  describe '#receive payload with picture url' do
    before do
      stub_request(:head, 'http://valid.image').to_return(status: 200, headers: {"Content-Type" => "image/jpeg"})
      stub_request(:head, 'http://invalid.image').to_return(status: 200, headers: {"Content-Type" => "text/html"})
    end

    it 'should publish a tweet without a picture if image url is not valid' do
      event = Event.new
      event.agent = agents(:bob_weather_agent)
      event.payload = {:text => 'whatever', :pic => 'http://invalid.image'}
      event.save!

      Agents::WeiboPublishAgent.async_receive(@checker.id, [event.id])
      expect(@sent_messages.count).to eq(1)
      expect(@sent_pictures.count).to eq(0)
      expect(@checker.events.count).to eq(1)
    end

    it 'should publish a tweet along with a picture if image url is valid' do
      event = Event.new
      event.agent = agents(:bob_weather_agent)
      event.payload = {:text => 'whatever', :pic => 'http://valid.image'}
      event.save!

      Agents::WeiboPublishAgent.async_receive(@checker.id, [event.id])
      expect(@sent_messages.count).to eq(0)
      expect(@sent_pictures.count).to eq(1)
      expect(@checker.events.count).to eq(1)
    end
  end

  describe '#working?' do
    it 'checks if events have been received within the expected receive period' do
      expect(@checker).not_to be_working # No events received
      Agents::WeiboPublishAgent.async_receive(@checker.id, [@event.id])
      expect(@checker.reload).to be_working # Just received events
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working # More time has passed than the expected receive period without any new events
    end
  end
end
