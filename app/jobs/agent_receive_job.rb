class AgentReceiveJob < ActiveJob::Base
  # Given an Agent id and an array of Event ids, load the Agent, call #receive on it with the Event objects, and then
  # save it with an updated `last_receive_at` timestamp.
  def perform(agent_id, event_ids)
    Agent.with_execution_lock(agent_id) do |agent|
      next if agent.unavailable?

      agent.receive(Event.where(:id => event_ids).order(:id))
      agent.last_receive_at = Time.now
      agent.save!
    rescue => e
      agent.error "Exception during receive. #{e.message}: #{e.backtrace.join("\n")}"
      raise
    end
  end
end
