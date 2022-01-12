require 'rails_helper'

describe AgentRunner do
  context "without traps" do
    before do
      allow_any_instance_of(Rufus::Scheduler).to receive(:every)
      allow_any_instance_of(AgentRunner).to receive(:set_traps)
      @agent_runner = AgentRunner.new
    end

    after(:each) do
      @agent_runner.stop
      AgentRunner.class_variable_set(:@@agents, [])
    end

    context "#run" do
      before do
        allow(@agent_runner).to receive(:run_workers)
      end

      it "runs until stop is called" do
        expect_any_instance_of(Rufus::Scheduler).to receive(:join)
        Thread.new { while @agent_runner.instance_variable_get(:@running) != false do sleep 0.1; @agent_runner.stop end }
        @agent_runner.run
      end

      it "handles signals" do
        @agent_runner.instance_variable_set(:@signal_queue, ['TERM'])
        @agent_runner.run
      end
    end

    context "#load_workers" do
      before do
        AgentRunner.class_variable_set(:@@agents, [HuginnScheduler, DelayedJobWorker])
      end

      it "loads all workers" do
        workers = @agent_runner.send(:load_workers)
        expect(workers).to be_a(Hash)
        expect(workers.keys).to eq(['HuginnScheduler', 'DelayedJobWorker'])
      end

      it "loads only the workers specified in the :only option" do
        agent_runner = AgentRunner.new(only: HuginnScheduler)
        workers = agent_runner.send(:load_workers)
        expect(workers.keys).to eq(['HuginnScheduler'])
        agent_runner.stop
      end

      it "does not load workers specified in the :except option" do
        agent_runner = AgentRunner.new(except: HuginnScheduler)
        workers = agent_runner.send(:load_workers)
        expect(workers.keys).to eq(['DelayedJobWorker'])

        agent_runner.stop
      end
    end

    context "running workers" do
      before do
        AgentRunner.class_variable_set(:@@agents, [HuginnScheduler, DelayedJobWorker])
        allow_any_instance_of(HuginnScheduler).to receive(:setup)
        allow_any_instance_of(DelayedJobWorker).to receive(:setup)
      end

      context "#run_workers" do
        it "runs all the workers" do
          expect_any_instance_of(HuginnScheduler).to receive(:run!)
          expect_any_instance_of(DelayedJobWorker).to receive(:run!)
          @agent_runner.send(:run_workers)
        end

        it "kills no long active workers" do
          expect_any_instance_of(HuginnScheduler).to receive(:run!)
          expect_any_instance_of(DelayedJobWorker).to receive(:run!)
          @agent_runner.send(:run_workers)
          AgentRunner.class_variable_set(:@@agents, [DelayedJobWorker])
          expect_any_instance_of(HuginnScheduler).to receive(:stop!)
          @agent_runner.send(:run_workers)
        end
      end

      context "#restart_dead_workers" do
        before do
          allow_any_instance_of(HuginnScheduler).to receive(:setup)
          allow_any_instance_of(DelayedJobWorker).to receive(:setup)
          @agent_runner.send(:run_workers)

        end
        it "restarts dead workers" do
          expect_any_instance_of(HuginnScheduler).to receive(:thread) { OpenStruct.new(alive?: false) }
          expect_any_instance_of(HuginnScheduler).to receive(:run!)
          @agent_runner.send(:restart_dead_workers)
        end
      end
    end
  end

  context "#set_traps" do
    it "sets traps for INT TERM and QUIT" do
      agent_runner = AgentRunner.new
      expect(Signal).to receive(:trap).with('INT')
      expect(Signal).to receive(:trap).with('TERM')
      expect(Signal).to receive(:trap).with('QUIT')
      agent_runner.set_traps

      agent_runner.stop
    end
  end
end
