class AgentPropagateJob < ActiveJob::Base
  queue_as :default

  def perform
    Agent.receive!
  end
end
