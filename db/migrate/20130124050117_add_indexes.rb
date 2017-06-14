class AddIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :links, [:receiver_id, :source_id]
  end
end
