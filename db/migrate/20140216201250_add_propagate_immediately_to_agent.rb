class AddPropagateImmediatelyToAgent < ActiveRecord::Migration[4.2]
  def up
    add_column :agents, :propagate_immediately, :boolean, :default => false, :null => false
  end

  def down
    remove_column :agents, :propagate_immediately
  end
end
