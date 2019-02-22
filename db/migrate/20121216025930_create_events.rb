class CreateEvents < ActiveRecord::Migration[4.2]
  def change
    create_table :events do |t|
      t.integer :user_id
      t.integer :agent_id
      t.decimal :lat, :precision => 15, :scale => 10
      t.decimal :lng, :precision => 15, :scale => 10
      t.text :payload

      t.timestamps
    end

    add_index :events, [:user_id, :created_at]
    add_index :events, [:agent_id, :created_at]
  end
end
