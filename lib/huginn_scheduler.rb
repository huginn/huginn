require 'rufus/scheduler'

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

  def cleanup_failed_jobs!
    first_to_delete = Delayed::Job.where.not(failed_at: nil).order("failed_at DESC").offset(ENV['FAILED_JOBS_TO_KEEP'].try(:to_i) || 100).limit(ENV['FAILED_JOBS_TO_KEEP'].try(:to_i) || 100).pluck(:failed_at).first
    Delayed::Job.where(["failed_at <= ?", first_to_delete]).delete_all if first_to_delete.present?
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

    @rufus_scheduler.join
  end
end
