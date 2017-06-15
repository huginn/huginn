class AddControlLinks < ActiveRecord::Migration[4.2]
  def change
    create_table :control_links do |t|
      t.integer :controller_id, null: false
      t.integer :control_target_id, null: false

      t.timestamps
    end

    add_index :control_links, [:controller_id, :control_target_id], unique: true
    add_index :control_links, :control_target_id
  end
end
