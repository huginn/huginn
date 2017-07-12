class AddCachedDatesToAgent < ActiveRecord::Migration[4.2]
  def up
    add_column :agents, :last_event_at, :datetime
    execute "UPDATE agents SET last_event_at = (SELECT created_at FROM events WHERE events.agent_id = agents.id ORDER BY id DESC LIMIT 1)"

    add_column :agents, :last_error_log_at, :datetime
    execute "UPDATE agents SET last_error_log_at = (SELECT created_at FROM agent_logs WHERE agent_logs.agent_id = agents.id AND agent_logs.level >= 4 ORDER BY id DESC LIMIT 1)"
  end

  def down
    remove_column :agents, :last_event_at
    remove_column :agents, :last_error_log_at
  end
end
