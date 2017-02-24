class ResetDataOutputAgents < ActiveRecord::Migration[4.2]
  def up
    Agents::DataOutputAgent.find_each do |agent|
      agent.memory = {}
      agent.save(validate: false)
      agent.latest_events(true)
    end
  end
end
