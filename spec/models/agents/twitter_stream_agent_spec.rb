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
        @agent.memory[:filter_counts][:keyword1].should == 2
        @agent.memory[:filter_counts][:keyword2].should == 1
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
        @agent.memory[:filter_counts][:'keyword1-1'].should == 4 # it stores on the first keyword
        @agent.memory[:filter_counts][:keyword2].should == 2
      end

      it 'removes unused keys' do
        @agent.memory[:filter_counts] = {:keyword1 => 2, :keyword2 => 3, :keyword3 => 4}
        @agent.save!
        @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})
        @agent.reload.memory[:filter_counts].should == { 'keyword1' => 3, 'keyword2' => 3 }
      end
    end

    context "when generate is set to 'events'" do
      it 'emits events immediately' do
        lambda {
          @agent.process_tweet('keyword1', {:text => "something", :user => {:name => "Mr. Someone"}})
        }.should change { @agent.events.count }.by(1)

        @agent.events.last.payload.should == {
          'filter' => 'keyword1',
          'text' => "something",
          'user' => { 'name' => "Mr. Someone" }
        }
      end

      it 'handles keyword sets too' do
        @agent.options[:filters][0] = %w[keyword1-1 keyword1-2 keyword1-3]
        @agent.save!

        lambda {
          @agent.process_tweet('keyword1-2', {:text => "something", :user => {:name => "Mr. Someone"}})
        }.should change { @agent.events.count }.by(1)

        @agent.events.last.payload.should == {
          'filter' => 'keyword1-1',
          'text' => "something",
          'user' => { 'name' => "Mr. Someone" }
        }
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