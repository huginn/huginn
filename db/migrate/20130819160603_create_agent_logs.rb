class CreateAgentLogs < ActiveRecord::Migration[4.2]
  def change
    create_table :agent_logs do |t|
      t.integer :agent_id, :null => false
      t.text :message, :null => false
      t.integer :level, :default => 3, :null => false
      t.integer :inbound_event_id
      t.integer :outbound_event_id

      t.timestamps
    end
  end
end
