if Rails.configuration.active_job.queue_adapter == :delayed_job
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
      scope :failed, -> { where("failed_at IS NOT NULL") }
    end

    database_deadlocks_when_using_optimized_strategy = lambda do
      ENV["DATABASE_ADAPTER"] == "mysql2"
    end

    Delayed::Backend::ActiveRecord.configure do |config|
      config.reserve_sql_strategy = :default_sql
    end if database_deadlocks_when_using_optimized_strategy.call
  end
elsif Rails.configuration.active_job.queue_adapter == :sidekiq
  require 'sidekiq'
  require 'sidekiq-failures'
  require 'sidekiq/web'

  Sidekiq::Web.set :sessions, false

  Sidekiq.configure_server do |config|
    config.redis = { url: ENV['REDIS_URL'].presence || 'redis://localhost:6379/1' }
    config.failures_max_count = (ENV['FAILED_JOBS_TO_KEEP'].presence || 100).to_i
    config.failures_default_mode = :exhausted
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: ENV['REDIS_URL'].presence || 'redis://localhost:6379/1' }
    config.default_worker_options = {queue: 'default', retry: 5}
  end
end
