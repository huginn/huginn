require 'rufus/scheduler'

class HuginnScheduler
  FAILED_JOBS_TO_KEEP = 100
  attr_accessor :mutex

  def initialize
    @rufus_scheduler = Rufus::Scheduler.new
    self.mutex = Mutex.new
  end

  def stop
    @rufus_scheduler.stop
  end

  def run!
    tzinfo_friendly_timezone = ActiveSupport::TimeZone::MAPPING[ENV['TIMEZONE'].present? ? ENV['TIMEZONE'] : "Pacific Time (US & Canada)"]

    # Schedule event propagation.
    @rufus_scheduler.every '1m' do
      propagate!
    end

    # Schedule event cleanup.
    @rufus_scheduler.cron "0 0 * * * " + tzinfo_friendly_timezone do
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
    first_to_delete = Delayed::Job.where.not(failed_at: nil).order("failed_at DESC").offset(num_to_keep).limit(num_to_keep).pluck(:failed_at).first
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
