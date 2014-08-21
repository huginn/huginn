class CreateChains < ActiveRecord::Migration
  def change
    create_table :chains do |t|
      t.integer :runner_id
      t.integer :target_id

      t.timestamps
    end

    add_index :chains, [:runner_id, :target_id], unique: true
    add_index :chains, :target_id
  end
end
