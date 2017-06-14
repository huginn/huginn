class AddMemoryToAgents < ActiveRecord::Migration[4.2]
  def change
    add_column :agents, :memory, :text
  end
end
