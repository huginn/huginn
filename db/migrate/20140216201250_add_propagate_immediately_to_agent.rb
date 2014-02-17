class AddPropagateImmediatelyToAgent < ActiveRecord::Migration
  def up
    add_column :agents, :propagate_immediately, :boolean, :default => false, :null => false
    execute "UPDATE agents SET propagate_immediately = 0"
  end

  def down
    remove_column :agents, :propagate_immediately
  end
end
