class AddSharedToAgents < ActiveRecord::Migration
  class Agents < ActiveRecord::Base
  end

  def change
    add_column :agents, :shared, :boolean, :default => false
    add_index :agents, [:shared]
  end
end
