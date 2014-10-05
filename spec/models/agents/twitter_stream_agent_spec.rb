require 'spec_helper'

describe Agents::TwitterStreamAgent do
  before do
    @opts = {
      :consumer_key => "---",
      :consumer_secret => "---",
      :oauth_token => "---",
      :oauth_token_secret => "---",
      :filters => %w[keyword1 keyword2],
      :expected_update_period_in_days => "2",
      :generate => "events"
    }

    @agent = Agents::TwitterStreamAgent.new(:name => "HuginnBot", :options => @opts)
    @agent.service = services(:generic)
    @agent.user = users(:bob)
    @agent.save!
  end

  describe '#process_tweet' do
    context "when generate is set to 'counts'" do
      before do
        @agent.options[:generate] = 'counts'
      end

      it 'records counts' do
        @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword2', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})

        @agent.reload
        expect(@agent.memory[:filter_counts][:keyword1]).to eq(2)
        expect(@agent.memory[:filter_counts][:keyword2]).to eq(1)
      end

      it 'records counts for keyword sets as well' do
        @agent.options[:filters][0] = %w[keyword1-1 keyword1-2 keyword1-3]
        @agent.save!

        @agent.process_tweet('keyword2', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword2', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword1-1', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword1-2', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword1-3', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword1-1', {:text => "something", :user => {:name => "Mr. Someone"}})

        @agent.reload
        expect(@agent.memory[:filter_counts][:'keyword1-1']).to eq(4) # it stores on the first keyword
        expect(@agent.memory[:filter_counts][:keyword2]).to eq(2)
      end

      it 'removes unused keys' do
        @agent.memory[:filter_counts] = {:keyword1 => 2, :keyword2 => 3, :keyword3 => 4}
        @agent.save!
        @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})
        expect(@agent.reload.memory[:filter_counts]).to eq({ 'keyword1' => 3, 'keyword2' => 3 })
      end
    end

    context "when generate is set to 'events'" do
      it 'emits events immediately' do
        expect {
          @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})
        }.to change { @agent.events.count }.by(1)

        expect(@agent.events.last.payload).to eq({
          'filter' => 'keyword1',
          'text' => "something",
          'user' => { 'name' => "Mr. Someone" }
        })
      end

      it 'handles keyword sets too' do
        @agent.options[:filters][0] = %w[keyword1-1 keyword1-2 keyword1-3]
        @agent.save!

        expect {
          @agent.process_tweet('keyword1-2', {:text => "something", :user => {:name => "Mr. Someone"}})
        }.to change { @agent.events.count }.by(1)

        expect(@agent.events.last.payload).to eq({
          'filter' => 'keyword1-1',
          'text' => "something",
          'user' => { 'name' => "Mr. Someone" }
        })
      end
    end
  end

  describe '#check' do
    context "when generate is set to 'counts'" do
      before do
        @agent.options[:generate] = 'counts'
        @agent.save!
      end

      it 'emits events' do
        @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword2', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})

        expect {
          @agent.reload.check
        }.to change { @agent.events.count }.by(2)

        expect(@agent.events[-1].payload[:filter]).to eq('keyword1')
        expect(@agent.events[-1].payload[:count]).to eq(2)

        expect(@agent.events[-2].payload[:filter]).to eq('keyword2')
        expect(@agent.events[-2].payload[:count]).to eq(1)

        expect(@agent.memory[:filter_counts]).to eq({})
      end
    end

    context "when generate is not set to 'counts'" do
      it 'does nothing' do
        @agent.memory[:filter_counts] = { :keyword1 => 2 }
        @agent.save!
        expect {
          @agent.reload.check
        }.not_to change { Event.count }
        expect(@agent.memory[:filter_counts]).to eq({})
      end
    end
  end
end
