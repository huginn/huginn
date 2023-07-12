class AgentCheckJob < ActiveJob::Base
  # Given an Agent id, load the Agent, call #check on it, and then save it with an updated `last_check_at` timestamp.
  def perform(agent_id)
    error = nil

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.transaction(requires_new: true) do
        agent = Agent.lock.find_by(id: agent_id)
        return if !agent || agent.unavailable?

        agent.check
        agent.last_check_at = Time.now
        agent.save!
      rescue StandardError => e
        agent&.error "Exception during check. #{e.message}: #{e.backtrace.join("\n")}"
        error = e
      end
    end

    raise error if error
  end
end
