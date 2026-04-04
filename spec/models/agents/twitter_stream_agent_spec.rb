require 'rails_helper'

describe Agents::TwitterStreamAgent do
  before do
    @opts = {
      consumer_key: "---",
      consumer_secret: "---",
      oauth_token: "---",
      oauth_token_secret: "---",
      filters: %w[keyword1 keyword2],
      expected_update_period_in_days: "2",
      generate: "events",
      include_retweets: "false"
    }

    @agent = Agents::TwitterStreamAgent.new(name: "HuginnBot", options: @opts)
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
        @agent.process_tweet('keyword1', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword2', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword1', { text: "something", user: { name: "Mr. Someone" } })

        @agent.reload
        expect(@agent.memory[:filter_counts][:keyword1]).to eq(2)
        expect(@agent.memory[:filter_counts][:keyword2]).to eq(1)
      end

      it 'records counts for keyword sets as well' do
        @agent.options[:filters][0] = %w[keyword1-1 keyword1-2 keyword1-3]
        @agent.save!

        @agent.process_tweet('keyword2', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword2', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword1-1', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword1-2', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword1-3', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword1-1', { text: "something", user: { name: "Mr. Someone" } })

        @agent.reload
        expect(@agent.memory[:filter_counts][:'keyword1-1']).to eq(4) # it stores on the first keyword
        expect(@agent.memory[:filter_counts][:keyword2]).to eq(2)
      end

      it 'removes unused keys' do
        @agent.memory[:filter_counts] = { keyword1: 2, keyword2: 3, keyword3: 4 }
        @agent.save!
        @agent.process_tweet('keyword1', { text: "something", user: { name: "Mr. Someone" } })
        expect(@agent.reload.memory[:filter_counts]).to eq({ 'keyword1' => 3, 'keyword2' => 3 })
      end
    end

    context "when generate is set to 'events'" do
      it 'emits events immediately' do
        expect {
          @agent.process_tweet('keyword1', { text: "something", user: { name: "Mr. Someone" } })
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
          @agent.process_tweet('keyword1-2', { text: "something", user: { name: "Mr. Someone" } })
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
        @agent.process_tweet('keyword1', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword2', { text: "something", user: { name: "Mr. Someone" } })
        @agent.process_tweet('keyword1', { text: "something", user: { name: "Mr. Someone" } })

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
        @agent.memory[:filter_counts] = { keyword1: 2 }
        @agent.save!
        expect {
          @agent.reload.check
        }.not_to(change { Event.count })
        expect(@agent.memory[:filter_counts]).to eq({})
      end
    end
  end

  context "#setup_worker" do
    it "ensures the dependencies are available" do
      expect(Agents::TwitterStreamAgent).to receive(:warn).with(Agents::TwitterStreamAgent.twitter_dependencies_missing)
      expect(Agents::TwitterStreamAgent).to receive(:dependencies_missing?) { true }
      expect(Agents::TwitterStreamAgent.setup_worker).to eq(false)
    end

    it "returns now workers if no agent is active" do
      @agent.destroy
      expect(Agents::TwitterStreamAgent.active).to be_empty
      expect(Agents::TwitterStreamAgent.setup_worker).to eq([])
    end

    it "returns a worker for an active agent" do
      expect(Agents::TwitterStreamAgent.active).to eq([@agent])
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
      agent2.options[:filters] = ['agent2']
      agent2.save!
      expect(Agents::TwitterStreamAgent.active.order(:id).pluck(:id)).to eq([@agent.id, agent2.id])

      workers = Agents::TwitterStreamAgent.setup_worker
      filter_to_agent_map = workers.first.config[:filter_to_agent_map]
      expect(filter_to_agent_map.keys).to eq(['keyword1', 'keyword2', 'agent2'])
      expect(filter_to_agent_map['keyword1']).to eq([@agent])
      expect(filter_to_agent_map['agent2']).to eq([agent2])
    end
  end

  describe Agents::TwitterStreamAgent::Worker do
    before(:each) do
      @mock_agent = double
      @config = { agent: @agent, config: { filter_to_agent_map: { 'agent' => [@mock_agent] } } }
      @worker = Agents::TwitterStreamAgent::Worker.new(@config)
      @worker.instance_variable_set(:@recent_tweets, [])
      # mock(@worker).schedule_in(Agents::TwitterStreamAgent::Worker::RELOAD_TIMEOUT)
      @worker.setup!(nil, Mutex.new)
    end

    def build_tweet(attrs = {})
      Twitter::Tweet.new({
        id: 123,
        id_str: "123",
        text: "agent",
        user: { name: "Mock User" },
      }.merge(attrs))
    end

    context "#run" do
      it "starts the stream" do
        expect(@worker).to receive(:stream!).with(['agent'], @agent) {
          @worker.instance_variable_set(:@stopping, true)
        }
        @worker.run
      end

      it "yields received tweets" do
        expect(@worker).to receive(:stream!).with(['agent'], @agent) { |_filters, _agent, &block|
          block.call(build_tweet(text: "hello", id_str: "hello"))
          @worker.instance_variable_set(:@stopping, true)
        }
        expect(@worker).to receive(:handle_status).with(an_instance_of(Twitter::Tweet))
        @worker.run
      end

      it "logs and retries on stream errors" do
        allow(@worker).to receive(:sleep) do
          @worker.instance_variable_set(:@stopping, true)
        end
        expect(@worker).to receive(:stream!).with(['agent'], @agent).and_raise(StandardError, 'woups')
        expect(@worker).to receive(:warn).with(a_string_matching(/Twitter error: StandardError: woups/))
        expect(@worker).to receive(:warn).with(a_string_matching(/Sleeping for 10 seconds/))
        @worker.run
      end

      it "uses the network reconnect backoff when the stream closes" do
        allow(@worker).to receive(:sleep) do
          @worker.instance_variable_set(:@stopping, true)
        end
        expect(@worker).to receive(:stream!).with(['agent'], @agent)
        expect(@worker).to receive(:warn).with(a_string_matching(/reconnecting in 0.25 seconds/))
        expect(@worker).to receive(:warn).with(a_string_matching(/Sleeping for 0.25 seconds/))
        @worker.run
      end
    end

    context "#stop" do
      it "stops the thread" do
        client = instance_double(Twitter::Streaming::Client, close: nil)
        @worker.instance_variable_set(:@client, client)
        expect(client).to receive(:close)
        expect(@worker).to receive(:terminate_thread!)
        @worker.stop
      end
    end

    context "stream!" do
      def streaming_config
        double.tap do |config|
          allow(config).to receive(:consumer_key=)
          allow(config).to receive(:consumer_secret=)
          allow(config).to receive(:access_token=)
          allow(config).to receive(:access_token_secret=)
        end
      end

      it "initializes Twitter::Streaming::Client and filters by track" do
        client = instance_double(Twitter::Streaming::Client)
        expect(Twitter::Streaming::Client).to receive(:new).and_yield(streaming_config).and_return(client)
        expect(client).to receive(:filter).with(track: "agent")
        @worker.send(:stream!, ['agent'], @agent)
      end

      it "samples when no filters are given" do
        client = instance_double(Twitter::Streaming::Client)
        expect(Twitter::Streaming::Client).to receive(:new).and_yield(streaming_config).and_return(client)
        expect(client).to receive(:sample)
        @worker.send(:stream!, [], @agent)
      end

      it "yields every status received" do
        client = instance_double(Twitter::Streaming::Client)
        allow(Twitter::Streaming::Client).to receive(:new).and_yield(streaming_config).and_return(client)
        expect(client).to receive(:filter).with(track: "agent").and_yield(build_tweet(text: "hello", id_str: "hello"))

        @worker.send(:stream!, ['agent'], @agent) do |status|
          expect(status).to be_a(Twitter::Tweet)
          expect(status.text).to eq("hello")
        end
      end
    end

    context "#restart_if_stale!" do
      it "restarts stale streams" do
        @worker.instance_variable_set(:@active_at, 91.seconds.ago)
        expect(@worker).to receive(:warn).with(a_string_matching(/Got no data for awhile/))
        expect(@worker).to receive(:restart!)
        @worker.send(:restart_if_stale!)
      end

      it "does nothing for fresh streams" do
        @worker.instance_variable_set(:@active_at, Time.now)
        expect(@worker).not_to receive(:restart!)
        @worker.send(:restart_if_stale!)
      end
    end

    context "#handle_reconnect!" do
      it "caps repeated application failures at the max reconnect sleep" do
        @worker.instance_variable_set(:@reconnect_retries, 10)
        @worker.send(:reset_backoff_strategy!, :application)
        expect(@worker).to receive(:warn).with(a_string_matching(/Oops, tried too many times!/))
        expect(@worker).to receive(:sleep).with(60.seconds)
        @worker.send(:handle_reconnect!, :application)
        expect(@worker.instance_variable_get(:@reconnect_retries)).to eq(0)
      end

      it "uses linear network reconnect steps" do
        expect(@worker.send(:reconnect_timeout, :network)).to eq(0.25)
        expect(@worker.send(:reconnect_timeout, :network)).to eq(0.5)
      end

      it "resets the backoff when reconnect type changes" do
        expect(@worker.send(:reconnect_timeout, :network)).to eq(0.25)
        expect(@worker.send(:reconnect_timeout, :network)).to eq(0.5)
        expect(@worker.send(:reconnect_timeout, :application)).to eq(10)
      end
    end

    context "#handle_status" do
      it "skips retweets" do
        @worker.send(:handle_status, build_tweet(text: "retweet", retweeted_status: { one: true }))
        expect(@worker.instance_variable_get(:'@recent_tweets')).not_to include('123')
      end

      it "includes retweets if configured" do
        @agent.options[:include_retweets] = 'true'
        @agent.save!
        @worker.send(:handle_status, build_tweet(text: "retweet", id: 1234, id_str: "1234", retweeted_status: { one: true }))
        expect(@worker.instance_variable_get(:'@recent_tweets')).to include('1234')
      end

      it "deduplicates tweets" do
        @worker.send(:handle_status, build_tweet(text: "dup", id: 1, id_str: "1"))
        expect(@worker).to receive(:puts).with(anything) { |text| expect(text).to match(/Skipping/) }
        @worker.send(:handle_status, build_tweet(text: "dup", id: 1, id_str: "1"))
        expect(@worker.instance_variable_get(:'@recent_tweets').select { it == '1' }.length).to eq 1
      end

      it "calls the agent to process the tweet" do
        expect(@mock_agent).to receive(:name) { 'mock' }
        expect(@mock_agent).to receive(:process_tweet).with('agent',
                                                            { text: 'agent', id: 123, id_str: '123', user: { name: 'Mock User' }, expanded_text: 'agent' })
        expect(@worker).to receive(:puts).with(a_string_matching(/received/))
        @worker.send(:handle_status, build_tweet)
        expect(@worker.instance_variable_get(:'@recent_tweets')).to include('123')
      end

      it "ignores non-tweet streaming events" do
        event = Twitter::Streaming::StallWarning.new(code: "FALLING_BEHIND")
        expect(@mock_agent).not_to receive(:process_tweet)
        @worker.send(:handle_status, event)
      end
    end
  end
end
