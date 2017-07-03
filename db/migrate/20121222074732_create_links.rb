class CreateLinks < ActiveRecord::Migration[4.2]
  def change
    create_table :links do |t|
      t.integer :source_id
      t.integer :receiver_id

      t.timestamps
    end

    add_index :links, [:source_id, :receiver_id]
  end
end
