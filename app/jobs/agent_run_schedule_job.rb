class AgentRunScheduleJob < ActiveJob::Base
  queue_as :default

  def perform(time)
    Agent.run_schedule(time)
  end
end
