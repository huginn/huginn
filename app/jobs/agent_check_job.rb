class AgentCheckJob < ActiveJob::Base
  # Given an Agent id, load the Agent, call #check on it, and then save it with an updated `last_check_at` timestamp.
  def perform(agent_id)
    Agent.with_execution_lock(agent_id) do |agent|
      next if agent.unavailable?

      agent.check
      agent.last_check_at = Time.now
      agent.save!
    rescue => e
      agent.error "Exception during check. #{e.message}: #{e.backtrace.join("\n")}"
      raise
    end
  end
end
