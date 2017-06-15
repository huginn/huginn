class CreateAgents < ActiveRecord::Migration[4.2]
  def change
    create_table :agents do |t|
      t.integer :user_id
      t.text :options
      t.string :type
      t.string :name
      t.string :schedule
      t.integer :events_count
      t.datetime :last_check_at
      t.datetime :last_receive_at
      t.integer :last_checked_event_id

      t.timestamps
    end

    add_index :agents, [:user_id, :created_at]
    add_index :agents, :type
    add_index :agents, :schedule
  end
end
