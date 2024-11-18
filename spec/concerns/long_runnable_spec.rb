require 'rails_helper'

class TestWorker < LongRunnable::Worker
  def stop; end
  def terminate; end
  def runl; end
end

describe LongRunnable do
  class LongRunnableAgent < Agent
    include LongRunnable

    def default_options
      { test: 'test' }
    end
  end

  before(:each) do
    @agent = LongRunnableAgent.new
  end

  it 'start_worker? defaults to true' do
    expect(@agent.start_worker?).to be_truthy
  end

  it 'should build the worker_id' do
    expect(@agent.worker_id).to eq('LongRunnableAgent--bf21a9e8fbc5a3846fb05b4fa0859e0917b2202f')
  end

  context '#setup_worker' do
    it 'returns active agent workers' do
      expect(LongRunnableAgent).to receive(:active) { [@agent] }
      workers = LongRunnableAgent.setup_worker
      expect(workers.length).to eq(1)
      expect(workers.first).to be_a(LongRunnableAgent::Worker)
      expect(workers.first.agent).to eq(@agent)
    end

    it 'returns an empty array when no agent is active' do
      expect(LongRunnableAgent).to receive(:active) { [] }
      workers = LongRunnableAgent.setup_worker
      expect(workers.length).to eq(0)
    end
  end

  describe LongRunnable::Worker do
    before(:each) do
      @agent = double('agent')
      @stoppable_worker = TestWorker.new(agent: @agent, id: 'test1234')
      @worker = LongRunnable::Worker.new(agent: @agent, id: 'test1234')
      @scheduler = Rufus::Scheduler.new
      @worker.setup!(@scheduler, Mutex.new)
      @stoppable_worker.setup!(@scheduler, Mutex.new)
    end

    after(:each) do
      @worker.thread.terminate if @worker.thread && !@skip_thread_terminate
      @scheduler.shutdown(:wait)
    end

    it 'calls boolify of the agent' do
      expect(@agent).to receive(:boolify).with('true') { true }
      expect(@worker.boolify('true')).to be_truthy
    end

    it 'expects run to be overriden' do
      expect { @worker.run }.to raise_error(StandardError)
    end

    context '#run!' do
      it 'runs the agent worker' do
        expect(@worker).to receive(:run)
        @worker.run!.join
      end

      it 'stops when rescueing a SystemExit' do
        expect(@worker).to receive(:run) { raise SystemExit }
        expect(@worker).to receive(:stop!)
        @worker.run!.join
      end

      it 'creates an agent log entry for a generic exception' do
        allow(STDERR).to receive(:puts)
        expect(@worker).to receive(:run) { raise 'woups' }
        expect(@agent).to receive(:error).with(/woups/)
        @worker.run!.join
      end
    end

    context '#stop!' do
      it 'terminates the thread' do
        expect(@worker).to receive(:terminate_thread!)
        @worker.stop!
      end

      it 'gracefully stops the worker' do
        expect(@stoppable_worker).to receive(:stop)
        @stoppable_worker.stop!
      end
    end

    context '#terminate_thread!' do
      before do
        @skip_thread_terminate = true
        mock_thread = double('mock_thread')
        allow(@worker).to receive(:thread) { mock_thread }
      end

      it 'terminates the thread' do
        expect(@worker.thread).to receive(:terminate)
        expect(@worker.thread).not_to receive(:wakeup)
        expect(@worker.thread).to receive(:status) { 'run' }
        @worker.terminate_thread!
      end

      it 'wakes up sleeping threads after termination' do
        expect(@worker.thread).to receive(:terminate)
        expect(@worker.thread).to receive(:wakeup)
        expect(@worker.thread).to receive(:status) { 'sleep' }
        @worker.terminate_thread!
      end
    end

    context '#restart!' do
      it 'stops, setups and starts the worker' do
        expect(@worker).to receive(:stop!)
        expect(@worker).to receive(:setup!).with(@worker.scheduler, @worker.mutex)
        expect(@worker).to receive(:run!)
        expect(@worker).to receive(:puts).with(anything) { |text| expect(text).to match(/Restarting/) }
        @worker.restart!
      end
    end

    context 'scheduling' do
      it 'schedules tasks once' do
        expect(@worker.scheduler).to receive(:send).with(:schedule_in, 1.hour, tag: 'test1234')
        @worker.schedule_in 1.hour do noop; end
      end

      it 'schedules repeating tasks' do
        expect(@worker.scheduler).to receive(:send).with(:every, 1.hour, tag: 'test1234')
        @worker.every 1.hour do noop; end
      end

      it 'allows the cron syntax' do
        expect(@worker.scheduler).to receive(:send).with(:cron, '0 * * * *', tag: 'test1234')
        @worker.cron '0 * * * *' do noop; end
      end
    end
  end
end
