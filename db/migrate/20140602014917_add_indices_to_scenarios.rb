class AddIndicesToScenarios < ActiveRecord::Migration[4.2]
  def change
    add_index :scenarios, [:user_id, :guid], :unique => true
    add_index :scenario_memberships, :agent_id
    add_index :scenario_memberships, :scenario_id
  end
end
