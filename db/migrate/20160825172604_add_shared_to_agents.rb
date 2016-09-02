class AddSharedToAgents < ActiveRecord::Migration
  def change
    add_column :agents, :shared, :boolean, :default => false
    add_index :agents, [:shared]
  end
end
