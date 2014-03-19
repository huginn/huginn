class CreatePendingEvents < ActiveRecord::Migration
  def change
    create_table :pending_events do |t|
      t.integer :user_id
      t.integer :agent_id
      t.decimal :lat, :precision => 15, :scale => 10
      t.decimal :lng, :precision => 15, :scale => 10
      t.datetime :emits_at, :null => false
      t.boolean :scheduled, :default => false
      t.text :payload

      t.timestamps
    end

    add_index :pending_events, [:user_id, :emits_at]
    add_index :pending_events, [:agent_id, :emits_at]
  end
end
