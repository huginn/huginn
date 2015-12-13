require 'rails_helper'

describe Agents::TwitterRetweetAgent do
  before do
    @options = { :expected_receive_period_in_days => "2" }
    @retweet_agent = described_class.new(name: 'RetweetingFiend', options: @options)
    @retweet_agent.service = services(:generic)
    @retweet_agent.user = users(:bob)
    @retweet_agent.save!

    @event1 = Event.new
    @event1.agent = agents(:bob_twitter_user_agent)
    @event1.payload = { id: 123, text: 'So awesome.. gotta retweet' }
    @event1.save!

    @event2 = Event.new
    @event2.agent = agents(:bob_twitter_user_agent)
    @event2.payload = { id: 456, text: 'Something Justin Bieber said' }
    @event2.save!
  end

  describe '#receive' do
    before do
      @tweet1 = Twitter::Tweet.new(
        id: @event1.payload[:id],
        text: @event1.payload[:text]
      )
      @tweet2 = Twitter::Tweet.new(
        id: @event2.payload[:id],
        text: @event2.payload[:text]
      )
    end

    context 'when the twitter client succeeds in retweeting' do
      context 'single incoming event' do
        it 'should retweet the tweet from the payload' do
          mock(@retweet_agent.twitter).retweet([@tweet1])
          @retweet_agent.receive([@event1])
        end
      end

      context 'multiple incoming event' do
        it 'should retweet both tweets from the payload' do
          mock(@retweet_agent.twitter).retweet([@tweet1, @tweet2])
          @retweet_agent.receive([@event1, @event2])
        end
      end
    end

    context 'when the twitter client fails retweeting' do
      before do
        stub(@retweet_agent.twitter).retweet(anything) {
          raise Twitter::Error.new('uh oh')
        }
      end

      it 'should create an event with tweet info and the error message' do
        @retweet_agent.receive([@event1, @event2])
        failure_event = @retweet_agent.events.last
        expect(failure_event.payload[:error]).to eq('uh oh')
        expect(failure_event.payload[:tweets]).to eq(
          {
            @event1.payload[:id].to_s => @event1.payload[:text],
            @event2.payload[:id].to_s => @event2.payload[:text]
          }
        )
      end
    end
  end

  describe '#working?' do
    before do
      stub.any_instance_of(Twitter::REST::Client).retweet(anything)
    end

    it 'checks if events have been received within the expected receive period' do
      expect(@retweet_agent).not_to be_working # No events received
      described_class.async_receive(@retweet_agent.id, [@event1.id])
      expect(@retweet_agent.reload).to be_working # Just received events
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@retweet_agent.reload).not_to be_working # More time has passed than the expected receive period without any new events
    end
  end
end

