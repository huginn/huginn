class AddIndexes < ActiveRecord::Migration
  def change
    add_index :links, [:receiver_id, :source_id]
  end
end
