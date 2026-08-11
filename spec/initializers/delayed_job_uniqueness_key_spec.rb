require "rails_helper"

RSpec.describe "delayed_job uniqueness_key" do
  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    original_delay_jobs = Delayed::Worker.delay_jobs
    ActiveJob::Base.queue_adapter = :delayed_job
    Delayed::Worker.delay_jobs = true
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original_adapter
    Delayed::Worker.delay_jobs = original_delay_jobs
  end

  it "stores the job's uniqueness key" do
    AgentRunScheduleJob.perform_later("every_1m")

    expect(Delayed::Job.last.uniqueness_key).to eq("agent_run_schedule/every_1m")
  end

  it "skips a duplicate job for the same schedule" do
    expect {
      2.times { AgentRunScheduleJob.perform_later("every_1m") }
    }.to change(Delayed::Job, :count).by(1)
  end

  it "enqueues jobs for different schedules independently" do
    expect {
      AgentRunScheduleJob.perform_later("every_1m")
      AgentRunScheduleJob.perform_later("every_1h")
    }.to change(Delayed::Job, :count).by(2)
  end

  it "returns false and records an enqueue error for a duplicate" do
    AgentRunScheduleJob.perform_later("every_1m")

    attempted = nil
    result = AgentRunScheduleJob.perform_later("every_1m") { |job| attempted = job }

    expect(result).to be(false)
    expect(attempted).not_to be_successfully_enqueued
    expect(attempted.enqueue_error).to be_a(DelayedJobUniquenessKeyAdapter::DuplicateJobError)
  end

  it "does not deduplicate jobs without a uniqueness key" do
    expect(Delayed::Job).not_to receive(:transaction)

    expect {
      2.times { AgentCleanupExpiredJob.perform_later }
    }.to change(Delayed::Job, :count).by(2)
  end

  it "releases the key when the job permanently fails" do
    AgentRunScheduleJob.perform_later("every_1m")
    job = Delayed::Job.last

    Delayed::Worker.lifecycle.run_callbacks(:failure, Delayed::Worker.new, job) do
      job.fail!
    end

    expect(job.reload.uniqueness_key).to be_nil
    expect { AgentRunScheduleJob.perform_later("every_1m") }
      .to change(Delayed::Job, :count).by(1)
  end
end
