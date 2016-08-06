class RemoveQueueFromEmailDigestAgentMemory < ActiveRecord::Migration
  def up
    Agents::EmailDigestAgent.all.each do |agent|
      agent.memory.delete("queue")
      agent.save!
    end
  end
end
