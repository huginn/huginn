class AddMemoryToAgents < ActiveRecord::Migration
  def change
    add_column :agents, :memory, :text
  end
end
