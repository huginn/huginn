require "rails_helper"

class WatchdogTestJob
  def perform; end
end

describe DelayedJobWatchdog::Worker do # rubocop:disable Metrics/BlockLength
  self.use_transactional_tests = false

  let(:queue) { "watchdog-test-#{SecureRandom.hex(8)}" }
  let(:worker) { Delayed::Worker.new }

  before do
    allow(Delayed::Worker).to receive(:delay_jobs).and_return(true)
    allow(Delayed::Worker).to receive(:queues).and_return([queue])
  end

  let!(:job) { Delayed::Job.enqueue(WatchdogTestJob.new, queue: queue) }

  after do
    Delayed::Job.where(queue: queue).delete_all
  end

  def abandon
    job.update!(locked_by: "dead worker", locked_at: Delayed::Job.db_time_now - Delayed::Worker.max_run_time - 1)
  end

  it "executes an available job and releases its execution lock" do
    expect(worker.work_off(1)).to eq([1, 0])
    expect(Delayed::Job.exists?(job.id)).to be(false)
    expect(Delayed::Job.advisory_lock_exists?("huginn:job:#{job.id}")).to be(false)
  end

  it "does not overwrite an expired reservation while its previous execution owns the lock" do
    abandon
    acquired = Queue.new
    release = Queue.new
    holder = Thread.new do
      Delayed::Job.with_advisory_lock!("huginn:job:#{job.id}", timeout_seconds: 0) do
        acquired << true
        release.pop
      end
    end
    expect(acquired.pop(timeout: 3)).to be(true)
    expect(worker.work_off(1)).to eq([0, 0])
    expect(job.reload.locked_by).to eq("dead worker")
    expect(job.attempts).to eq(0)
  ensure
    release&.push(true)
    holder&.join(3)
    holder&.kill
  end

  it "records an abandoned attempt and applies backoff instead of immediately executing it" do
    abandon
    expect(worker.work_off(1)).to eq([0, 1])
    expect(job.reload.attempts).to eq(1)
    expect(job.locked_by).to be_nil
    expect(job.last_error).to include("previous worker exited")
    expect(job.run_at).to be > Delayed::Job.db_time_now
    expect(worker.work_off(1)).to eq([0, 0])
  end

  it "quarantines a job after repeated abandoned attempts" do
    abandon
    job.update!(attempts: Delayed::Worker.max_attempts - 1)
    expect(worker.work_off(1)).to eq([0, 1])
    expect(job.reload.failed_at).not_to be_nil
    expect(worker.work_off(1)).to eq([0, 0])
  end

  it "preserves ordinary failure handling" do
    allow_any_instance_of(WatchdogTestJob).to receive(:perform).and_raise("expected failure")
    expect(worker.work_off(1)).to eq([0, 1])
    expect(job.reload.attempts).to eq(1)
    expect(job.last_error).to include("expected failure")
  end
end
