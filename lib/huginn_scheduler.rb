require 'rufus/scheduler'

class Rufus::Scheduler
  SCHEDULER_AGENT_TAG = Agents::SchedulerAgent.name

  class Job
    # Store an ID of SchedulerAgent in this job.
    def scheduler_agent_id=(id)
      self[:scheduler_agent_id] = id
    end

    # Extract an ID of SchedulerAgent if any.
    def scheduler_agent_id
      self[:scheduler_agent_id]
    end

    # Return a SchedulerAgent tied to this job.  Return nil if it is
    # not found or disabled.
    def scheduler_agent
      agent_id = scheduler_agent_id or return nil

      Agent.of_type(Agents::SchedulerAgent).active.find_by(id: agent_id)
    end
  end

  # Get all jobs tied to any SchedulerAgent
  def scheduler_agent_jobs
    jobs(tag: SCHEDULER_AGENT_TAG)
  end

  # Get a job tied to a given SchedulerAgent
  def scheduler_agent_job(agent)
    scheduler_agent_jobs.find { |job|
      job.scheduler_agent_id == agent.id
    }
  end

  # Schedule or reschedule a job for a given SchedulerAgent and return
  # the running job.  Return nil if unscheduled.
  def schedule_scheduler_agent(agent)
    job = scheduler_agent_job(agent)

    if agent.disabled?
      if job
        puts "Unscheduling SchedulerAgent##{agent.id} (disabled)"
        job.unschedule
      end
      nil
    else
      if job
        return job if agent.memory['scheduled_at'] == job.scheduled_at.to_i
        puts "Rescheduling SchedulerAgent##{agent.id}"
        job.unschedule
      else
        puts "Scheduling SchedulerAgent##{agent.id}"
      end

      agent_id = agent.id

      job = schedule_cron agent.options['schedule'], tag: SCHEDULER_AGENT_TAG do |job|
        job.scheduler_agent_id = agent_id

        if scheduler_agent = job.scheduler_agent
          scheduler_agent.check!
        else
          puts "Unscheduling SchedulerAgent##{job.scheduler_agent_id} (disabled or deleted)"
          job.unschedule
        end
      end
      # Make sure the job is associated with a SchedulerAgent before
      # it is triggered.
      job.scheduler_agent_id = agent_id

      agent.memory['scheduled_at'] = job.scheduled_at.to_i
      agent.save

      job
    end
  end

  # Schedule or reschedule jobs for all SchedulerAgents and unschedule
  # orphaned jobs if any.
  def schedule_scheduler_agents
    scheduled_jobs = Agent.of_type(Agents::SchedulerAgent).map { |scheduler_agent|
      schedule_scheduler_agent(scheduler_agent)
    }.compact

    (scheduler_agent_jobs - scheduled_jobs).each { |job|
      puts "Unscheduling SchedulerAgent##{job.scheduler_agent_id} (orphaned)"
      job.unschedule
    }
  end
end

class HuginnScheduler
  attr_accessor :mutex

  def initialize
    @rufus_scheduler = Rufus::Scheduler.new
  end

  def stop
    @rufus_scheduler.stop
  end

  def run_schedule(time)
    with_mutex do
      puts "Queuing schedule for #{time}"
      Agent.delay.run_schedule(time)
    end
  end

  def propagate!
    with_mutex do
      puts "Queuing event propagation"
      Agent.delay.receive!
    end
  end

  def cleanup_expired_events!
    with_mutex do
      puts "Running event cleanup"
      Event.delay.cleanup_expired!
    end
  end

  def with_mutex
    ActiveRecord::Base.connection_pool.with_connection do
      mutex.synchronize do
        yield
      end
    end
  end

  def run!
    self.mutex = Mutex.new

    tzinfo_friendly_timezone = ActiveSupport::TimeZone::MAPPING[ENV['TIMEZONE'].present? ? ENV['TIMEZONE'] : "Pacific Time (US & Canada)"]

    # Schedule event propagation.

    @rufus_scheduler.every '1m' do
      propagate!
    end

    # Schedule event cleanup.

    @rufus_scheduler.cron "0 0 * * * " + tzinfo_friendly_timezone do
      cleanup_expired_events!
    end

    # Schedule repeating events.

    %w[1m 2m 5m 10m 30m 1h 2h 5h 12h 1d 2d 7d].each do |schedule|
      @rufus_scheduler.every schedule do
        run_schedule "every_#{schedule}"
      end
    end

    # Schedule events for specific times.

    # Times are assumed to be in PST for now.  Can store a user#timezone later.
    24.times do |hour|
      @rufus_scheduler.cron "0 #{hour} * * * " + tzinfo_friendly_timezone do
        if hour == 0
          run_schedule "midnight"
        elsif hour < 12
          run_schedule "#{hour}am"
        elsif hour == 12
          run_schedule "noon"
        else
          run_schedule "#{hour - 12}pm"
        end
      end
    end

    # Schedule Scheduler Agents

    @rufus_scheduler.every '1m' do
      @rufus_scheduler.schedule_scheduler_agents
    end

    @rufus_scheduler.join
  end
end
