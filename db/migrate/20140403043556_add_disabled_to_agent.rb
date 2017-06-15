class AddDisabledToAgent < ActiveRecord::Migration[4.2]
  def change
    add_column :agents, :disabled, :boolean, :default => false, :null => false
  end
end
