require "rails_helper"
require "stringio"
require "timeout"
require "tmpdir"
require_relative "../../lib/delayed_job_watchdog/master"

WatchdogHangingJob = Struct.new(:agent_id, :pid_file) do
  def perform
    Agent.with_execution_lock(agent_id) do
      File.write(pid_file, Process.pid.to_s) if pid_file
      Process.kill(:STOP, Process.pid)
    end
  end
end

class WatchdogCompletedJob
  def perform; end
end

WatchdogSleepingJob = Struct.new(:agent_id) do
  def perform
    Agent.with_execution_lock(agent_id) { sleep 30 }
  end
end

describe DelayedJobWatchdog::Master do # rubocop:disable Metrics/BlockLength
  self.use_transactional_tests = false

  let(:queue) { "watchdog-master-test-#{SecureRandom.hex(8)}" }
  let(:log) { StringIO.new }
  let(:config) do
    Delayed::Master::Config.new.tap do |configuration|
      configuration.before_fork do ActiveRecord::Base.connection_handler.clear_all_connections!(:all) end
      configuration.after_fork { ActiveRecord::Base.establish_connection }
    end
  end
  let(:master) do
    Struct.new(:config, :logger, :callbacks, :workers).new(
      config, Logger.new(log), Delayed::Master::Callbacks.new(config), Delayed::Master::SafeArray.new
    )
  end

  before do
    allow(Delayed::Worker).to receive(:delay_jobs).and_return(true)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DELAYED_JOB_SHUTDOWN_GRACE", "10").and_return("0.2")
  end

  after do
    Delayed::Job.where(queue: [queue, "#{queue}:other"]).delete_all
  end

  def run_worker(runtime: 0.3)
    setting = Delayed::Master::WorkerSetting.new(id: 0, max_threads: 1, queues: [queue], max_run_time: runtime)
    worker = Delayed::Master::Worker.new(setting: setting)
    Delayed::Master::Forker.new(master).call(worker)
    master.workers << worker
    Timeout.timeout(5) do Delayed::Master::Monitoring.new(master).send(:wait_pid, worker) end
    reaped = true
    expect(master.workers).to be_empty
  ensure
    if worker&.pid && !reaped
      begin
        Process.kill(:KILL, worker.pid)
        Process.waitpid(worker.pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
  end

  it "kills a stuck Agent owner, releases its DB locks and records the abandoned attempt" do
    agent = agents(:bob_weather_agent)
    job = Delayed::Job.enqueue(WatchdogHangingJob.new(agent.id), queue: queue)
    run_worker
    expect(log.string).to include("\"job_id\":#{job.id}", "#{Agent::EXECUTION_LOCK_PREFIX}#{agent.id}")
    expect(Delayed::Job.advisory_lock_exists?("huginn:job:#{job.id}")).to be(false)
    expect(Agent.advisory_lock_exists?("#{Agent::EXECUTION_LOCK_PREFIX}#{agent.id}")).to be(false)
    expect(job.reload.locked_by).not_to be_nil

    job.update!(locked_at: 1.day.ago)
    run_worker
    expect(job.reload.attempts).to eq(1)
    expect(job.locked_by).to be_nil
    expect(job.run_at).to be > Delayed::Job.db_time_now

    replacement = Delayed::Job.enqueue(WatchdogCompletedJob.new, queue: queue)
    run_worker(runtime: 2)
    expect(Delayed::Job.exists?(replacement.id)).to be(false)
  end

  it "rejects a threaded worker before forking" do
    setting = Delayed::Master::WorkerSetting.new(max_threads: 2)
    worker = Delayed::Master::Worker.new(setting: setting)
    expect { Delayed::Master::Forker.new(master).call(worker) }.to raise_error(ArgumentError, /one thread/)
    expect(worker.pid).to be_nil
  end

  it "unwinds a responsive Agent and records cancellation exactly once" do
    # Allow coverage and other at_exit handlers to finish before asserting a clean exit.
    allow(ENV).to receive(:fetch).with("DELAYED_JOB_SHUTDOWN_GRACE", "10").and_return("2")
    agent = agents(:bob_weather_agent)
    job = Delayed::Job.enqueue(WatchdogSleepingJob.new(agent.id), queue: queue)
    run_worker
    expect(job.reload.attempts).to eq(1)
    expect(job.locked_by).to be_nil
    expect(job.last_error).to include("worker execution deadline exceeded")
    expect(Agent.advisory_lock_exists?("#{Agent::EXECUTION_LOCK_PREFIX}#{agent.id}")).to be(false)
    expect(log.string).to include('"exit_status":0', '"signal":null')
  end

  it "keeps a sibling worker independent of a stuck child and its pipes" do
    stuck = Delayed::Job.enqueue(WatchdogHangingJob.new(agents(:bob_weather_agent).id), queue: queue)
    healthy = Delayed::Job.enqueue(WatchdogCompletedJob.new, queue: "#{queue}:other")
    monitors = [queue, "#{queue}:other"].map { |worker_queue|
      setting = Delayed::Master::WorkerSetting.new(id: 0, max_threads: 1, queues: [worker_queue], max_run_time: 0.3)
      worker = Delayed::Master::Worker.new(setting: setting)
      Delayed::Master::Forker.new(master).call(worker)
      master.workers << worker
      Thread.new { Delayed::Master::Monitoring.new(master).send(:wait_pid, worker) }
    }
    Timeout.timeout(5) do monitors.each(&:join) end
    expect(master.workers).to be_empty
    expect(described_class.channels).to be_empty
    expect(Delayed::Job.exists?(healthy.id)).to be(false)
    expect(stuck.reload.locked_by).not_to be_nil
  ensure
    monitors&.each do |monitor|
      monitor.kill
      monitor.join
    end
  end

  %i[TERM USR2].each do |signal| # rubocop:disable Metrics/BlockLength
    it "keeps the watchdog alive until children exit on #{signal}" do # rubocop:disable Metrics/BlockLength
      FileUtils.mkdir_p(Rails.root.join(".tmp"))
      directory = Dir.mktmpdir("watchdog-master-", Rails.root.join(".tmp"))
      child_pid_file = File.join(directory, "child.pid")
      restarted = File.join(directory, "restarted")
      configuration = File.join(directory, "master.rb")
      File.write(configuration, <<~RUBY)
        polling_interval 0.05
        monitor_interval 0.05
        pid_file #{File.join(directory, "master.pid").inspect}
        log_file #{File.join(directory, "master.log").inspect}
        before_fork { ActiveRecord::Base.connection_handler.clear_all_connections!(:all) }
        after_fork { ActiveRecord::Base.establish_connection }
        add_worker do |worker|
          worker.queues [#{queue.inspect}]
          worker.max_threads 1
          worker.max_processes 1
          worker.max_run_time 0.5
        end
      RUBY
      agent = agents(:bob_weather_agent)
      Delayed::Job.enqueue(WatchdogHangingJob.new(agent.id, child_pid_file), queue: queue)
      ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
      pid = fork {
        Process.setsid
        instance = Delayed::Master.new(["-c", configuration])
        instance.define_singleton_method(:exec) do |*_args| File.write(restarted, "yes") end
        instance.run
        exit! 0
      }
      Timeout.timeout(5) do
        sleep 0.01 until File.exist?(child_pid_file)
        Process.kill(signal, pid)
        _, status = Process.waitpid2(pid)
        pid = nil
        expect(status.exitstatus).to eq(0)
      end
      expect(Agent.advisory_lock_exists?("#{Agent::EXECUTION_LOCK_PREFIX}#{agent.id}")).to be(false)
      expect(File.exist?(restarted)).to eq(signal == :USR2)
    ensure
      if pid
        Process.kill(:KILL, -pid)
        Process.waitpid(pid)
      end
      FileUtils.remove_entry(directory) if directory
    end
  end
end
