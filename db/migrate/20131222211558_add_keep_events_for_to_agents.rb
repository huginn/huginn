class AddKeepEventsForToAgents < ActiveRecord::Migration
  def change
    add_column :agents, :keep_events_for, :integer, :null => false, :default => 0
  end
end
