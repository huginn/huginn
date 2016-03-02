class AddDeactivatedToAgents < ActiveRecord::Migration
  def change
    add_column :agents, :deactivated, :boolean, default: false
    add_index :agents, [:disabled, :deactivated]
  end
end
