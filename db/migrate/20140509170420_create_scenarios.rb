class CreateScenarios < ActiveRecord::Migration[4.2]
  def change
    create_table :scenarios do |t|
      t.string :name, :null => false
      t.integer :user_id, :null => false

      t.timestamps
    end

    add_column :users, :scenario_count, :integer, :null => false, :default => 0
  end
end
