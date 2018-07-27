require 'rails_helper'

describe Agents::TwitterActionAgent do
  describe '#receive' do
    before do
      @event1 = Event.new
      @event1.agent = agents(:bob_twitter_user_agent)
      @event1.payload = { id: 123, text: 'So awesome.. gotta retweet' }
      @event1.save!
      @tweet1 = Twitter::Tweet.new(
        id: @event1.payload[:id],
        text: @event1.payload[:text]
      )

      @event2 = Event.new
      @event2.agent = agents(:bob_twitter_user_agent)
      @event2.payload = { id: 456, text: 'Something Justin Bieber said' }
      @event2.save!
      @tweet2 = Twitter::Tweet.new(
        id: @event2.payload[:id],
        text: @event2.payload[:text]
      )
    end

    context 'when set up to retweet' do
      before do
        @agent = build_agent(
          'favorite' => 'false',
          'retweet' => 'true',
          'emit_error_events' => 'true'
        )
        @agent.save!
      end

      context 'when the twitter client succeeds retweeting' do
        it 'should retweet the tweets from the payload' do
          mock(@agent.twitter).retweet([@tweet1, @tweet2])
          @agent.receive([@event1, @event2])
        end
      end

      context 'when the twitter client fails retweeting' do
        it 'creates an event with tweet info and the error message' do
          stub(@agent.twitter).retweet(anything) {
            raise Twitter::Error.new('uh oh')
          }

          @agent.receive([@event1, @event2])

          failure_event = @agent.events.last
          expect(failure_event.payload[:error]).to eq('uh oh')
          expect(failure_event.payload[:tweets]).to eq(
            {
              @event1.payload[:id].to_s => @event1.payload[:text],
              @event2.payload[:id].to_s => @event2.payload[:text]
            }
          )
          expect(failure_event.payload[:agent_ids]).to match_array(
            [@event1.agent_id, @event2.agent_id]
          )
          expect(failure_event.payload[:event_ids]).to match_array(
            [@event2.id, @event1.id]
          )
        end
      end
    end

    context 'when set up to favorite' do
      before do
        @agent = build_agent(
          'favorite' => 'true',
          'retweet' => 'false',
          'emit_error_events' => 'true'
        )
        @agent.save!
      end

      context 'when the twitter client succeeds favoriting' do
        it 'should favorite the tweets from the payload' do
          mock(@agent.twitter).favorite([@tweet1, @tweet2])
          @agent.receive([@event1, @event2])
        end
      end

      context 'when the twitter client fails retweeting' do
        it 'creates an event with tweet info and the error message' do
          stub(@agent.twitter).favorite(anything) {
            raise Twitter::Error.new('uh oh')
          }

          @agent.receive([@event1, @event2])

          failure_event = @agent.events.last
          expect(failure_event.payload[:error]).to eq('uh oh')
          expect(failure_event.payload[:tweets]).to eq(
            {
              @event1.payload[:id].to_s => @event1.payload[:text],
              @event2.payload[:id].to_s => @event2.payload[:text]
            }
          )
          expect(failure_event.payload[:agent_ids]).to match_array(
            [@event1.agent_id, @event2.agent_id]
          )
          expect(failure_event.payload[:event_ids]).to match_array(
            [@event2.id, @event1.id]
          )
        end
      end
    end

    context 'with emit_error_events set to false' do
      let(:agent) { build_agent.tap(&:save!) }

      it 're-raises the exception on failure' do
        stub(agent.twitter).retweet(anything) {
          raise Twitter::Error.new('uh oh')
        }

        expect { agent.receive([@event1]) }.to raise_error(StandardError, /uh oh/)
      end

      it 'does not re-raise the exception on "already retweeted" error' do
        stub(agent.twitter).retweet(anything) {
          raise Twitter::Error::AlreadyRetweeted.new('You have already retweeted this tweet.')
        }

        expect { agent.receive([@event1]) }.not_to raise_error
      end

      it 'does not re-raise the exception on "already favorited" error' do
        stub(agent.twitter).retweet(anything) {
          raise Twitter::Error::AlreadyFavorited.new('You have already favorited this status.')
        }

        expect { agent.receive([@event1]) }.not_to raise_error
      end
    end
  end

  describe "#validate_options" do
    it 'the default options are valid' do
      agent = build_agent(described_class.new.default_options)

      expect(agent).to be_valid
    end

    context 'emit_error_events' do
      it 'can be set to true' do
        agent = build_agent(described_class.new.default_options.merge('emit_error_events' => 'true'))
        expect(agent).to be_valid
      end

      it 'must be a boolean' do
        agent = build_agent(described_class.new.default_options.merge('emit_error_events' => 'notbolean'))
        expect(agent).not_to be_valid
      end
    end

    it 'expected_receive_period_in_days must be set' do
      agent = build_agent(described_class.new.default_options.merge('expected_receive_period_in_days' => ''))
      expect(agent).not_to be_valid
    end

    context 'when set up to neither favorite or retweet' do
      it 'is invalid' do
        agent = build_agent(
          'favorite' => 'false',
          'retweet' => 'false',
        )

        expect(agent).not_to be_valid
      end
    end
  end

  describe '#working?' do
    before do
      stub.any_instance_of(Twitter::REST::Client).retweet(anything)
    end

    it 'checks if events have been received within the expected time period' do
      agent = build_agent
      agent.save!

      expect(agent).not_to be_working # No events received

      described_class.async_receive(agent.id, [events(:bob_website_agent_event)])
      expect(agent.reload).to be_working # Just received events

      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(agent.reload).not_to be_working # Too much time has passed
    end
  end

  def build_agent(options = {})
    described_class.new do |agent|
      agent.name = 'twitter stuff'
      agent.options = agent.default_options.merge(options)
      agent.service = services(:generic)
      agent.user = users(:bob)
    end
  end
end
