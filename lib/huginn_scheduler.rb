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

    if agent.unavailable?
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
  FAILED_JOBS_TO_KEEP = 100
  attr_accessor :mutex

  def initialize(options = {})
    @rufus_scheduler = Rufus::Scheduler.new(options)
    self.mutex = Mutex.new
  end

  def stop
    @rufus_scheduler.stop
  end

  def run!
    tzinfo_friendly_timezone = ActiveSupport::TimeZone::MAPPING[ENV['TIMEZONE'].presence || "Pacific Time (US & Canada)"]

    # Schedule event propagation.
    @rufus_scheduler.every '1m' do
      propagate!
    end

    # Schedule event cleanup.
    @rufus_scheduler.every ENV['EVENT_EXPIRATION_CHECK'].presence || '6h' do
      cleanup_expired_events!
    end

    # Schedule failed job cleanup.
    @rufus_scheduler.every '1h' do
      cleanup_failed_jobs!
    end

    # Schedule repeating events.
    %w[1m 2m 5m 10m 30m 1h 2h 5h 12h 1d 2d 7d].each do |schedule|
      @rufus_scheduler.every schedule do
        run_schedule "every_#{schedule}"
      end
    end

    # Schedule events for specific times.
    24.times do |hour|
      @rufus_scheduler.cron "0 #{hour} * * * " + tzinfo_friendly_timezone do
        run_schedule hour_to_schedule_name(hour)
      end
    end

    # Schedule Scheduler Agents

    @rufus_scheduler.every '1m' do
      @rufus_scheduler.schedule_scheduler_agents
    end

    @rufus_scheduler.join
  end

  private
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

  def cleanup_failed_jobs!
    num_to_keep = (ENV['FAILED_JOBS_TO_KEEP'].presence || FAILED_JOBS_TO_KEEP).to_i
    first_to_delete = Delayed::Job.where.not(failed_at: nil).order("failed_at DESC").offset(num_to_keep).limit(1).pluck(:failed_at).first
    Delayed::Job.where(["failed_at <= ?", first_to_delete]).delete_all if first_to_delete.present?
  end

  def hour_to_schedule_name(hour)
    if hour == 0
      "midnight"
    elsif hour < 12
      "#{hour}am"
    elsif hour == 12
      "noon"
    else
      "#{hour - 12}pm"
    end
  end

  def with_mutex
    ActiveRecord::Base.connection_pool.with_connection do
      mutex.synchronize do
        yield
      end
    end
  end
end
