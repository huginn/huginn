class AddDisabledToAgent < ActiveRecord::Migration
  def change
    add_column :agents, :disabled, :boolean, :default => false, :null => false
  end
end
