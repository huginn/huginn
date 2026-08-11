class AgentRunScheduleJob < ActiveJob::Base
  queue_as :default

  def perform(time)
    Agent.run_schedule(time)
  end

  def uniqueness_key
    "agent_run_schedule/#{arguments.first}"
  end
end
