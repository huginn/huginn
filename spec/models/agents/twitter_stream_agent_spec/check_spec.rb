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
    @agent.user = users(:bob)
    @agent.save!
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

        lambda {
          @agent.reload.check
        }.should change { @agent.events.count }.by(2)

        @agent.events[-1].payload[:filter].should == 'keyword1'
        @agent.events[-1].payload[:count].should == 2

        @agent.events[-2].payload[:filter].should == 'keyword2'
        @agent.events[-2].payload[:count].should == 1

        @agent.memory[:filter_counts].should == {}
      end
    end

    context "when generate is not set to 'counts'" do
      it 'does nothing' do
        @agent.memory[:filter_counts] = { :keyword1 => 2 }
        @agent.save!
        lambda {
          @agent.reload.check
        }.should_not change { Event.count }
        @agent.memory[:filter_counts].should == {}
      end
    end
  end
end