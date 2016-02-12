require 'rails_helper'
require 'huginn_scheduler'

describe HuginnScheduler do
  before(:each) do
    @rufus_scheduler = Rufus::Scheduler.new
    @scheduler = HuginnScheduler.new
    stub(@scheduler).setup {}
    @scheduler.setup!(@rufus_scheduler, Mutex.new)
  end

  after(:each) do
    @rufus_scheduler.shutdown(:wait)
  end

  it "schould register the schedules with the rufus scheduler and run" do
    mock(@rufus_scheduler).join
    scheduler = HuginnScheduler.new
    scheduler.setup!(@rufus_scheduler, Mutex.new)
    scheduler.run
  end

  it "should run scheduled agents" do
    mock(Agent).run_schedule('every_1h')
    mock.instance_of(IO).puts('Queuing schedule for every_1h')
    @scheduler.send(:run_schedule, 'every_1h')
  end

  it "should propagate events" do
    mock(Agent).receive!
    stub.instance_of(IO).puts
    @scheduler.send(:propagate!)
  end

  it "schould clean up expired events" do
    mock(Event).cleanup_expired!
    stub.instance_of(IO).puts
    @scheduler.send(:cleanup_expired_events!)
  end

  describe "#hour_to_schedule_name" do
    it "for 0h" do
      expect(@scheduler.send(:hour_to_schedule_name, 0)).to eq('midnight')
    end

    it "for the forenoon" do
      expect(@scheduler.send(:hour_to_schedule_name, 6)).to eq('6am')
    end

    it "for 12h" do
      expect(@scheduler.send(:hour_to_schedule_name, 12)).to eq('noon')
    end

    it "for the afternoon" do
      expect(@scheduler.send(:hour_to_schedule_name, 17)).to eq('5pm')
    end
  end

  describe "cleanup_failed_jobs!" do
    before do
      3.times do |i|
        Delayed::Job.create(failed_at: Time.now - i.minutes)
      end
      @keep = Delayed::Job.order(:failed_at)[1]
    end

    it "work with set FAILED_JOBS_TO_KEEP env variable" do
      expect { @scheduler.send(:cleanup_failed_jobs!) }.to change(Delayed::Job, :count).by(-1)
      expect { @scheduler.send(:cleanup_failed_jobs!) }.to change(Delayed::Job, :count).by(0)
      expect(@keep.id).to eq(Delayed::Job.order(:failed_at)[0].id)
    end


    it "work without the FAILED_JOBS_TO_KEEP env variable" do
      old = ENV['FAILED_JOBS_TO_KEEP']
      ENV['FAILED_JOBS_TO_KEEP'] = nil
      expect { @scheduler.send(:cleanup_failed_jobs!) }.to change(Delayed::Job, :count).by(0)
      ENV['FAILED_JOBS_TO_KEEP'] = old
    end
  end

  context "#setup_worker" do
    it "should return an array with an instance of itself" do
      workers = HuginnScheduler.setup_worker
      expect(workers).to be_a(Array)
      expect(workers.first).to be_a(HuginnScheduler)
      expect(workers.first.id).to eq('HuginnScheduler')
    end
  end
end

describe Rufus::Scheduler do
  before :each do
    Agent.delete_all

    @taoe, Thread.abort_on_exception = Thread.abort_on_exception, false
    @oso, @ose, $stdout, $stderr = $stdout, $stderr, StringIO.new, StringIO.new

    @scheduler = Rufus::Scheduler.new

    stub.any_instance_of(Agents::SchedulerAgent).second_precision_enabled { true }

    @agent1 = Agents::SchedulerAgent.new(name: 'Scheduler 1', options: { action: 'run', schedule: '*/1 * * * * *' }).tap { |a|
      a.user = users(:bob)
      a.save!
    }
    @agent2 = Agents::SchedulerAgent.new(name: 'Scheduler 2', options: { action: 'run', schedule: '*/1 * * * * *' }).tap { |a|
      a.user = users(:bob)
      a.save!
    }
  end

  after :each do
    @scheduler.shutdown(:wait)

    Thread.abort_on_exception = @taoe
    $stdout, $stderr = @oso, @ose
  end

  describe '#schedule_scheduler_agents' do
    it 'registers active SchedulerAgents' do
      @scheduler.schedule_scheduler_agents

      expect(@scheduler.scheduler_agent_jobs.map(&:scheduler_agent).sort_by(&:id)).to eq([@agent1, @agent2])
    end

    it 'unregisters disabled SchedulerAgents' do
      @scheduler.schedule_scheduler_agents

      @agent1.update!(disabled: true)

      @scheduler.schedule_scheduler_agents

      expect(@scheduler.scheduler_agent_jobs.map(&:scheduler_agent)).to eq([@agent2])
    end

    it 'unregisters deleted SchedulerAgents' do
      @scheduler.schedule_scheduler_agents

      @agent2.delete

      @scheduler.schedule_scheduler_agents

      expect(@scheduler.scheduler_agent_jobs.map(&:scheduler_agent)).to eq([@agent1])
    end
  end
end
