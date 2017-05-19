class CreateScenarioMemberships < ActiveRecord::Migration[4.2]
  def change
    create_table :scenario_memberships do |t|
      t.integer :agent_id, :null => false
      t.integer :scenario_id, :null => false

      t.timestamps
    end
  end
end
