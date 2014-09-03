require 'spec_helper'
require 'huginn_scheduler'

describe Rufus::Scheduler do
  before :each do
    @taoe, Thread.abort_on_exception = Thread.abort_on_exception, false
    @oso, @ose, $stdout, $stderr = $stdout, $stderr, StringIO.new, StringIO.new

    @scheduler = Rufus::Scheduler.new

    stub.any_instance_of(Agents::SchedulerAgent).second_precision_enabled { true }

    @agent1 = Agents::SchedulerAgent.new(name: 'Scheduler 1', options: { schedule: '*/1 * * * * *' }).tap { |a|
      a.user = users(:bob)
      a.save!
    }
    @agent2 = Agents::SchedulerAgent.new(name: 'Scheduler 2', options: { schedule: '*/1 * * * * *' }).tap { |a|
      a.user = users(:bob)
      a.save!
    }
  end

  after :each do
    @scheduler.shutdown

    Thread.abort_on_exception = @taoe
    $stdout, $stderr = @oso, @ose
  end

  describe '#schedule_scheduler_agents' do
    it 'registers active SchedulerAgents' do
      @scheduler.schedule_scheduler_agents

      expect(@scheduler.scheduler_agent_jobs.map(&:scheduler_agent)).to eq([@agent1, @agent2])
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
