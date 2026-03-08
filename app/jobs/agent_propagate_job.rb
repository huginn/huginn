class AgentPropagateJob < ActiveJob::Base
  queue_as :propagation

  def perform
    Agent.receive!
  end

  def self.can_enqueue?
    case queue_adapter.class.name # not using class since it would load adapter dependent gems
    when 'ActiveJob::QueueAdapters::DelayedJobAdapter'
      return Delayed::Job.where(failed_at: nil, queue: 'propagation').count == 0
    when 'ActiveJob::QueueAdapters::ResqueAdapter'
      return Resque.size('propagation') == 0 &&
             Resque.workers.select { |w| w.job && w.job['queue'] && w.job['queue']['propagation'] }.count == 0
    when 'ActiveJob::QueueAdapters::TestAdapter'
      return queue_adapter.enqueued_jobs.none? { |job|
        (job[:job] || job['job']) == self &&
          [job[:queue], job['queue'], job[:queue_name], job['queue_name']].compact.any? { |queue| queue.to_s == queue_name }
      }
    else
      raise NotImplementedError, "unsupported adapter: #{queue_adapter}"
    end
  end

end
