class AgentReemitJob < ActiveJob::Base
  # Given an Agent, re-emit all of agent's events up to (and including) `most_recent_event_id`
  def perform(agent, most_recent_event_id, delete_old_events = false)
    # `find_each` orders by PK, so events get re-created in the same order
    agent.events.where("id <= ?", most_recent_event_id).find_each do |event|
      event.reemit!
      event.destroy if delete_old_events
    end
  end
end
