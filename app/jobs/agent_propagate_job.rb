class AgentPropagateJob < ActiveJob::Base
  queue_as :propagation

  def perform
    Agent.receive!
  end

  def self.can_enqueue?
    if Rails.configuration.active_job.queue_adapter == :delayed_job &&
       Delayed::Job.where(failed_at: nil, queue: 'propagation').count > 0
      return false
    elsif Rails.configuration.active_job.queue_adapter == :resque &&
          (Resque.size('propagation') > 0 ||
           Resque.workers.select { |w| w.job && w.job['queue'] && w.job['queue']['propagation'] }.count > 0)
      return false
    end
    true
  end
end
