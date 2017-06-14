require 'rails_helper'

describe LongRunnable do
  class LongRunnableAgent < Agent
    include LongRunnable

    def default_options
      {test: 'test'}
    end
  end

  before(:each) do
    @agent = LongRunnableAgent.new
  end

  it "start_worker? defaults to true" do
    expect(@agent.start_worker?).to be_truthy
  end

  it "should build the worker_id" do
    expect(@agent.worker_id).to eq('LongRunnableAgent--bf21a9e8fbc5a3846fb05b4fa0859e0917b2202f')
  end

  context "#setup_worker" do
    it "returns active agent workers" do
      mock(LongRunnableAgent).active { [@agent] }
      workers = LongRunnableAgent.setup_worker
      expect(workers.length).to eq(1)
      expect(workers.first).to be_a(LongRunnableAgent::Worker)
      expect(workers.first.agent).to eq(@agent)
    end

    it "returns an empty array when no agent is active" do
      mock(LongRunnableAgent).active { [] }
      workers = LongRunnableAgent.setup_worker
      expect(workers.length).to eq(0)
    end
  end

  describe LongRunnable::Worker do
    before(:each) do
      @agent = Object.new
      @worker = LongRunnable::Worker.new(agent: @agent, id: 'test1234')
      @scheduler = Rufus::Scheduler.new
      @worker.setup!(@scheduler, Mutex.new)
    end

    after(:each) do
      @worker.thread.terminate if @worker.thread && !@skip_thread_terminate
      @scheduler.shutdown(:wait)
    end

    it "calls boolify of the agent" do
      mock(@agent).boolify('true') { true }
      expect(@worker.boolify('true')).to be_truthy
    end

    it "expects run to be overriden" do
      expect { @worker.run }.to raise_error(StandardError)
    end

    context "#run!" do
      it "runs the agent worker" do
        mock(@worker).run
        @worker.run!.join
      end

      it "stops when rescueing a SystemExit" do
        mock(@worker).run { raise SystemExit }
        mock(@worker).stop!
        @worker.run!.join
      end

      it "creates an agent log entry for a generic exception" do
        stub(STDERR).puts
        mock(@worker).run { raise "woups" }
        mock(@agent).error(/woups/)
        @worker.run!.join
      end
    end

    context "#stop!" do
      it "terminates the thread" do
        mock.proxy(@worker).terminate_thread!
        @worker.stop!
      end

      it "gracefully stops the worker" do
        mock(@worker).stop
        @worker.stop!
      end
    end

    context "#terminate_thread!" do
      before do
        @skip_thread_terminate = true
        mock_thread = Object.new
        stub(@worker).thread { mock_thread }
      end

      it "terminates the thread" do
        mock(@worker.thread).terminate
        do_not_allow(@worker.thread).wakeup
        mock(@worker.thread).status { 'run' }
        @worker.terminate_thread!
      end

      it "wakes up sleeping threads after termination" do
        mock(@worker.thread).terminate
        mock(@worker.thread).wakeup
        mock(@worker.thread).status { 'sleep' }
        @worker.terminate_thread!
      end
    end

    context "#restart!" do
      it "stops, setups and starts the worker" do
        mock(@worker).stop!
        mock(@worker).setup!(@worker.scheduler, @worker.mutex)
        mock(@worker).run!
        mock(@worker).puts(anything) { |text| expect(text).to match(/Restarting/) }
        @worker.restart!
      end
    end

    context "scheduling" do
      it "schedules tasks once" do
        mock(@worker.scheduler).send(:schedule_in, 1.hour, tag: 'test1234')
        @worker.schedule_in 1.hour do noop; end
      end

      it "schedules repeating tasks" do
        mock(@worker.scheduler).send(:every, 1.hour, tag: 'test1234')
        @worker.every 1.hour do noop; end
      end

      it "allows the cron syntax" do
        mock(@worker.scheduler).send(:cron, '0 * * * *', tag: 'test1234')
        @worker.cron '0 * * * *' do noop; end
      end
    end
  end
end
