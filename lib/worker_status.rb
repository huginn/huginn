module WorkerStatusDelayedJob
  def pending(start)
    Delayed::Job.pending.where("run_at <= ?", start).count
  end

  def awaiting_retry
    Delayed::Job.awaiting_retry.count
  end

  def recent_failures
    Delayed::Job.failed_jobs.where('failed_at > ?', 5.days.ago).count
  end

  [:jobs_path, :retries_path, :failures_path].each do |m|
    define_method(m) do
      Rails.application.routes.url_helpers.jobs_path
    end
  end
end

module WorkerStatusSidekiq
  def pending(_)
    Sidekiq::Queue.new.size
  end

  def awaiting_retry
    Sidekiq::RetrySet.new.size
  end

  def recent_failures
    Sidekiq::DeadSet.new.size
  end

  def jobs_path
    '/sidekiq'
  end

  def retries_path
    '/sidekiq/retries'
  end

  def failures_path
    '/sidekiq/morgue'
  end
end

class WorkerStatus
  extend "WorkerStatus#{Rails.configuration.active_job.queue_adapter.to_s.camelcase}".constantize
end
