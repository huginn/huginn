class AddKeepEventsForToAgents < ActiveRecord::Migration[4.2]
  def change
    add_column :agents, :keep_events_for, :integer, :null => false, :default => 0
  end
end
