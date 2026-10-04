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

  describe "automatic agent checks" do
    let(:agent) { agents(:bob_website_agent) }

    it "deduplicates repeated schedule runs per agent" do
      Agent.run_schedule(agent.schedule)
      expect {
        Agent.run_schedule(agent.schedule)
      }.not_to change(Delayed::Job, :count)
      expect(Delayed::Job.where(uniqueness_key: "agent_check/#{agent.id}").count).to eq(1)
    end

    it "enqueues different agents independently" do
      expect {
        Agent.async_check(agent.id, deduplicate: true)
        Agent.async_check(agents(:jane_website_agent).id, deduplicate: true)
      }.to change(Delayed::Job, :count).by(2)
    end

    it "does not deduplicate event deliveries or manual checks" do
      Agent.async_check(agent.id, deduplicate: true)

      expect {
        2.times do
          Agent.async_receive(agent.id, [events(:bob_website_agent_event).id])
        end
        2.times { Agent.async_check(agent.id) }
      }.to change(Delayed::Job, :count).by(4)
    end

    it "keeps the key while running or waiting for a retry" do
      Agent.async_check(agent.id, deduplicate: true)
      job = Delayed::Job.last
      job.update!(locked_at: Time.current, locked_by: "worker")

      expect { Agent.async_check(agent.id, deduplicate: true) }.not_to change(Delayed::Job, :count)

      job.update!(locked_at: nil, locked_by: nil, attempts: 1, run_at: 1.hour.from_now)
      expect { Agent.async_check(agent.id, deduplicate: true) }.not_to change(Delayed::Job, :count)
    end

    it "executes the serialized check and allows another run after completion" do
      Agent.async_check(agent.id, deduplicate: true)
      allow(Agent).to receive(:with_execution_lock).with(agent.id).and_yield(agent)
      expect(agent).to receive(:check)
      expect(Delayed::Worker.new.work_off).to eq([1, 0])

      expect { Agent.async_check(agent.id, deduplicate: true) }.to change(Delayed::Job, :count).by(1)
    end

    it "allows another run after permanent failure" do
      Agent.async_check(agent.id, deduplicate: true)
      job = Delayed::Job.last
      Delayed::Worker.lifecycle.run_callbacks(:failure, Delayed::Worker.new, job) do
        job.fail!
      end

      expect { Agent.async_check(agent.id, deduplicate: true) }.to change(Delayed::Job, :count).by(1)
    end

    it "deduplicates commands from both checks and events" do
      commander = Agents::CommanderAgent.create!(
        name: "Commander", user: users(:bob), schedule: "every_1h",
        options: { action: "run" }, control_targets: [agent]
      )

      expect { 2.times { commander.check } }.to change(Delayed::Job, :count).by(1)
      expect {
        commander.receive([events(:bob_website_agent_event), events(:bob_website_agent_event)])
      }.not_to change(Delayed::Job, :count)
    end

    it "deduplicates SchedulerAgent commands" do
      scheduler = Agents::SchedulerAgent.create!(
        name: "Scheduler", user: users(:bob),
        options: { action: "run", schedule: "0 * * * *" }, control_targets: [agent]
      )

      expect { 2.times { scheduler.control! } }.to change(Delayed::Job, :count).by(1)
    end

    [true, false].each do |schedule_first|
      it "coalesces schedules and commands with schedule_first=#{schedule_first}" do
        Agent.where.not(id: agent.id).update_all(schedule: "never")
        scheduler = Agents::SchedulerAgent.create!(
          name: "Scheduler", user: users(:bob),
          options: { action: "run", schedule: "0 * * * *" }, control_targets: [agent]
        )
        actions = [-> { Agent.run_schedule(agent.schedule) }, -> { scheduler.control! }]
        actions.reverse! unless schedule_first

        expect { actions.each(&:call) }.to change(Delayed::Job, :count).by(1)
      end
    end
  end
end
