module DelayedJobUniquenessKey
  def uniqueness_key
    job = ActiveJob::Base.deserialize(job_data)
    return unless job.respond_to?(:uniqueness_key)

    job.send(:deserialize_arguments_if_needed)
    job.uniqueness_key
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.prepend(DelayedJobUniquenessKey)

module DelayedJobUniquenessKeyAdapter
  require "active_job/enqueuing"

  class DuplicateJobError < ActiveJob::EnqueueError; end

  def enqueue(job, *args, **kwargs)
    enqueue_uniquely(job) { super }
  end

  def enqueue_at(job, *args, **kwargs)
    enqueue_uniquely(job) { super }
  end

  private

  def enqueue_uniquely(job, &block)
    uniqueness_key = job.try(:uniqueness_key)
    return yield unless uniqueness_key

    Delayed::Job.transaction(requires_new: true, &block)
  rescue ActiveRecord::RecordNotUnique
    raise DuplicateJobError, "duplicate uniqueness_key: #{uniqueness_key}"
  end
end

ActiveJob::QueueAdapters::DelayedJobAdapter.prepend(DelayedJobUniquenessKeyAdapter)

class DelayedJobUniquenessKeyPlugin < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.before(:enqueue) do |job|
      job.uniqueness_key = job.payload_object.try(:uniqueness_key)
    end

    lifecycle.after(:failure) do |_worker, job|
      job.update_column(:uniqueness_key, nil) if job.persisted? && job.uniqueness_key
    end
  end
end

Delayed::Worker.plugins << DelayedJobUniquenessKeyPlugin
Delayed::Worker.setup_lifecycle
