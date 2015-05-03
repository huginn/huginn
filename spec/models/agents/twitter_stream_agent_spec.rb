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
      @worker.setup
    end

    context "#run" do
      it "calls the agent to process the tweet" do
        stub.instance_of(IO).puts
        mock(@mock_agent).name { 'mock' }
        mock(@mock_agent).process_tweet('agent', {'text' => 'agent'})
        mock(@worker).stream!(['agent'], @agent).yields({'text' => 'agent'})

        @worker.run
      end
      it "skips retweets" do
        mock.instance_of(IO).puts('Skipping retweet: retweet')
        mock(@worker).stream!(['agent'], @agent).yields({'retweeted_status' => {'' => true}, 'text' => 'retweet'})

        @worker.run
      end

      it "deduplicates tweets" do
        mock.instance_of(IO).puts("dup")
        mock.instance_of(IO).puts("Skipping duplicate tweet: dup")
        # RR does not support multiple yield calls
        class DoubleYield < Agents::TwitterStreamAgent::Worker
          def stream!(_, __, &block)
            yield({'text' => 'dup'})
            yield({'text' => 'dup'})
          end
        end
        worker = DoubleYield.new(@config)

        worker.run
      end
    end

    context "#stream!" do
      before(:each) do
        @client_mock = mock!
        stub(@worker).client { @client_mock }
      end

      it "calls the sample method without filters" do
        @client_mock.sample
        @worker.send(:stream!, [], @mock_agent)
      end

      it "calls the filter method when filters are provided" do
        @client_mock.filter(track: 'filter')
        @worker.send(:stream!, ['filter'], @mock_agent)
      end

      it "only handles instances of Twitter::Tweet" do
        @client_mock.sample.yields(Object.new)
        expect { |blk| @worker.send(:stream!, [], @mock_agent, &blk) }.not_to yield_control
      end

      it "yields Hashes for received Twitter:Tweet instances" do
        @client_mock.sample.yields(Twitter::Tweet.new(id: '1234', text: 'test'))
        expect { |blk| @worker.send(:stream!, [], @mock_agent, &blk) }.to yield_with_args({'id' => '1234', 'text' => 'test'})
      end

      it "it backs of 60 seconds for every Twitter::Error::TooManyRequests exception rescued" do
        stub.instance_of(IO).puts
        mock(@worker).sleep(60)
        @client_mock.sample { raise Twitter::Error::TooManyRequests }
        @worker.send(:stream!, [], @mock_agent)
        @client_mock.sample { raise Twitter::Error::TooManyRequests }
        mock(@worker).sleep(120)
        @worker.send(:stream!, [], @mock_agent)
      end
    end

    context "#client" do
      it "initializes the client" do
        client = @worker.send(:client)
        expect(client).to be_a(Twitter::Streaming::Client)
        expect(client.access_token).to eq('1234token')
        expect(client.access_token_secret).to eq('56789secret')
      end
    end
  end
end
