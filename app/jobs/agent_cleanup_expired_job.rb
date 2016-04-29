class AgentCleanupExpiredJob < ActiveJob::Base
  queue_as :default

  def perform
    Event.cleanup_expired!
  end
end
