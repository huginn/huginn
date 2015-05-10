if Rails.configuration.active_job.queue_adapter == :delayed_job
  class WorkerStatus
    class << self
      def pending
        Delayed::Job.pending.where("run_at <= ?", start).count
      end

      def awaiting_retry
        Delayed::Job.awaiting_retry.count
      end

      def recent_failures
        Delayed::Job.failed.where('failed_at > ?', 5.days.ago).count
      end

      def jobs_path
        Rails.application.routes.url_helpers.jobs_path
      end
    end
  end
else
  class WorkerStatus
    class << self
      def pending
        Sidekiq::Queue.new.size
      end

      def awaiting_retry
        Sidekiq::RetrySet.new.size
      end

      def recent_failures
        Sidekiq::Failures.count
      end

      def jobs_path
        '/sidekiq'
      end
    end
  end
end
