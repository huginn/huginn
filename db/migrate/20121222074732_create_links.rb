class CreateLinks < ActiveRecord::Migration
  def change
    create_table :links do |t|
      t.integer :source_id
      t.integer :receiver_id

      t.timestamps
    end

    add_index :links, [:source_id, :receiver_id]
  end
end
