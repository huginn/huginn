Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_attempts = 5
Delayed::Worker.max_run_time = (ENV['DELAYED_JOB_MAX_RUNTIME'].presence || 2).to_i.minutes
Delayed::Worker.read_ahead = 5
Delayed::Worker.default_priority = 10
Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.sleep_delay = (ENV['DELAYED_JOB_SLEEP_DELAY'].presence || 10).to_f
Delayed::Worker.logger = Rails.logger

# Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))
# Delayed::Worker.logger.level = Logger::DEBUG

ActiveSupport.on_load(:delayed_job_active_record) do
  class Delayed::Job
    scope :pending, -> { where("locked_at IS NULL AND attempts = 0") }
    scope :awaiting_retry, -> { where("failed_at IS NULL AND attempts > 0 AND locked_at IS NULL") }
    scope :failed_jobs, -> { where("failed_at IS NOT NULL") }
  end

  database_deadlocks_when_using_optimized_strategy = lambda do
    ENV["DATABASE_ADAPTER"] == "mysql2"
  end

  Delayed::Backend::ActiveRecord.configure do |config|
    config.reserve_sql_strategy = :default_sql
  end if database_deadlocks_when_using_optimized_strategy.call
end
