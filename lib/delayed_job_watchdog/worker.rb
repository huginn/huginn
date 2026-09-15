# frozen_string_literal: true

require_relative "../delayed_job_watchdog"

module DelayedJobWatchdog
  class AbandonedJob < StandardError; end

  # Holds a DB execution lock across reservation, callbacks and persistence.
  module Worker
    attr_accessor :watchdog_client

    def start
      watchdog_client&.start
      super
    ensure
      watchdog_client&.close
    end

    protected

    def reserve_and_run_one_job
      if watchdog_client
        watchdog_client.perform { reserve_guarded_job }
      else
        reserve_guarded_job
      end
    end

    private

    def reserve_guarded_job
      scope = Delayed::Job.ready_to_run(name, self.class.max_run_time)
        .min_priority.max_priority.for_queues.by_priority
      scope.limit(self.class.read_ahead).pluck(:id).each do |id|
        result = Delayed::Job.with_advisory_lock_result(
          "huginn:job:#{id}", timeout_seconds: 0, disable_query_cache: true
        ) {
          # Recheck eligibility after acquiring the execution lock.  A stale
          # locked_at alone never grants permission to overwrite a live owner.
          job = scope.find_by(id: id)
          next unless job

          watchdog_client&.notify("job", job_id: job.id)
          if job.locked_by.present?
            recover_abandoned_job(job)
            next false
          end

          job = Delayed::Job.reserve_with_scope(scope.where(id: id), self, Delayed::Job.db_time_now)
          next unless job

          perform_guarded_job(job)
        }
        return result.result if result.lock_was_acquired? && !result.result.nil?
      end
      nil
    end

    def perform_guarded_job(job)
      operation = -> { self.class.lifecycle.run_callbacks(:perform, self, job) { run(job) } }
      watchdog_client ? watchdog_client.interruptible(&operation) : operation.call
    rescue Cancelled => e
      self.class.lifecycle.run_callbacks(:error, self, job) { handle_failed_job(job, e) } if job.persisted?
      false
    end

    def recover_abandoned_job(job)
      error = AbandonedJob.new("previous worker exited without completing the job")
      error.set_backtrace(caller)
      self.class.lifecycle.run_callbacks(:error, self, job) { handle_failed_job(job, error) }
    end
  end

  # Reports Agent lock ownership without an additional database query.
  module LockReporting
    def with_advisory_lock!(name, *args, **kwargs)
      client = DelayedJobWatchdog.current
      return super unless client

      acquired = false
      super do
        acquired = true
        raw = connection.raw_connection
        connection_id = raw.respond_to?(:thread_id) ? raw.thread_id : raw.backend_pid
        client.notify("lock_acquired", name: name, connection_id: connection_id)
        yield
      end
    ensure
      client.notify("lock_released", name: name) if acquired
    end
  end
end
