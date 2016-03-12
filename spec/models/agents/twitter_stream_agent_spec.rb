require 'rails_helper'

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

  context "#setup_worker" do
    it "ensures the dependencies are available" do
      mock(STDERR).puts(Agents::TwitterStreamAgent.twitter_dependencies_missing)
      mock(Agents::TwitterStreamAgent).dependencies_missing? { true }
      expect(Agents::TwitterStreamAgent.setup_worker).to eq(false)
    end

    it "returns now workers if no agent is active" do
      mock(Agents::TwitterStreamAgent).active { [] }
      expect(Agents::TwitterStreamAgent.setup_worker).to eq([])
    end

    it "returns a worker for an active agent" do
      mock(Agents::TwitterStreamAgent).active { [@agent] }
      workers = Agents::TwitterStreamAgent.setup_worker
      expect(workers).to be_a(Array)
      expect(workers.length).to eq(1)
      expect(workers.first).to be_a(Agents::TwitterStreamAgent::Worker)
      filter_to_agent_map = workers.first.config[:filter_to_agent_map]
      expect(filter_to_agent_map.keys).to eq(['keyword1', 'keyword2'])
      expect(filter_to_agent_map.values).to eq([[@agent], [@agent]])
    end

    it "correctly maps keywords to agents" do
      agent2 = @agent.dup
      agent2.id = 123455
      agent2.options[:filters] = ['agent2']
      mock(Agents::TwitterStreamAgent).active { [@agent, agent2] }

      workers = Agents::TwitterStreamAgent.setup_worker
      filter_to_agent_map = workers.first.config[:filter_to_agent_map]
      expect(filter_to_agent_map.keys).to eq(['keyword1', 'keyword2', 'agent2'])
      expect(filter_to_agent_map['keyword1']).to eq([@agent])
      expect(filter_to_agent_map['agent2']).to eq([agent2])
    end
  end

  describe Agents::TwitterStreamAgent::Worker do
    before(:each) do
      @mock_agent = mock!
      @config = {agent: @agent, config: {filter_to_agent_map: {'agent' => [@mock_agent]}}}
      @worker = Agents::TwitterStreamAgent::Worker.new(@config)
      @worker.instance_variable_set(:@recent_tweets, [])
      #mock(@worker).schedule_in(Agents::TwitterStreamAgent::Worker::RELOAD_TIMEOUT)
      @worker.setup!(nil, Mutex.new)
    end

    context "#run" do
      before(:each) do
        mock(EventMachine).run.yields
        mock(EventMachine).add_periodic_timer(3600)
      end

      it "starts the stream" do
        mock(@worker).stream!(['agent'], @agent)
        mock(Thread).stop
        @worker.run
      end

      it "yields received tweets" do
        mock(@worker).stream!(['agent'], @agent).yields('status' => 'hello')
        mock(@worker).handle_status('status' => 'hello')
        mock(Thread).stop
        @worker.run
      end
    end

    context "#stop" do
      it "stops the thread" do
        mock(@worker).terminate_thread!
        @worker.stop
      end
    end

    context "stream!" do
      def stub_without(method = nil)
        stream_stub = stub!
        stream_stub.each_item if method != :each_item
        stream_stub.on_error if method != :on_error
        stream_stub.on_no_data if method != :on_no_data
        stream_stub.on_max_reconnects if method != :on_max_reconnects
        stub(Twitter::JSONStream).connect { stream_stub }
        stream_stub
      end

      it "initializes Twitter::JSONStream" do
        mock(Twitter::JSONStream).connect({:path=>"/1/statuses/filter.json?track=agent",
                                           :ssl=>true, :oauth=>{:consumer_key=>"twitteroauthkey",
                                           :consumer_secret=>"twitteroauthsecret",
                                           :access_key=>"1234token",
                                           :access_secret=>"56789secret"}
                                          }) { stub_without }
        @worker.send(:stream!, ['agent'], @agent)
      end

      context "callback handling" do
        it "logs error messages" do
          stub_without(:on_error).on_error.yields('woups')
          mock(STDERR).puts(anything) { |text| expect(text).to match(/woups/) }
          mock(STDERR).puts(anything) { |text| expect(text).to match(/Sleeping/) }
          mock(@worker).sleep(15)
          mock(@worker).restart!
          @worker.send(:stream!, ['agent'], @agent)
        end

        it "stop when no data was received"do
          stub_without(:on_no_data).on_no_data.yields
          mock(@worker).restart!
          mock(STDERR).puts(anything)
          @worker.send(:stream!, ['agent'], @agent)
        end

        it "sleeps for 60 seconds on_max_reconnects" do
          stub_without(:on_max_reconnects).on_max_reconnects.yields
          mock(STDERR).puts(anything)
          mock(@worker).sleep(60)
          mock(@worker).restart!
          @worker.send(:stream!, ['agent'], @agent)
        end

        it "yields every status received" do
          stub_without(:each_item).each_item.yields({'text' => 'hello'})
          @worker.send(:stream!, ['agent'], @agent) do |status|
            expect(status).to eq({'text' => 'hello'})
          end
        end
      end
    end

    context "#handle_status" do
      it "skips retweets" do
        @worker.send(:handle_status, {'text' => 'retweet', 'retweeted_status' => {one: true}, 'id_str' => '123' })
        expect(@worker.instance_variable_get(:'@recent_tweets')).not_to include('123')
      end

      it "deduplicates tweets" do
        @worker.send(:handle_status, {'text' => 'dup', 'id_str' => '1'})
        mock(@worker).puts(anything) { |text| expect(text).to match(/Skipping/) }
        @worker.send(:handle_status, {'text' => 'dup', 'id_str' => '1'})
        expect(@worker.instance_variable_get(:'@recent_tweets').select { |str| str == '1' }.length).to eq 1
      end

      it "calls the agent to process the tweet" do
        mock(@mock_agent).name { 'mock' }
        mock(@mock_agent).process_tweet('agent', {'text' => 'agent'})
        mock(@worker).puts(anything) { |text| expect(text).to match(/received/) }
        @worker.send(:handle_status, {'text' => 'agent', 'id_str' => '123'})
        expect(@worker.instance_variable_get(:'@recent_tweets')).to include('123')
      end
    end
  end
end
