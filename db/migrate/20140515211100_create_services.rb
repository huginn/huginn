class CreateServices < ActiveRecord::Migration[4.2]
  def change
    create_table :services do |t|
      t.integer :user_id, null: false
      t.string :provider, null: false
      t.string :name, null: false
      t.text :token, null: false
      t.text :secret
      t.text :refresh_token
      t.datetime :expires_at
      t.boolean :global, default: false
      t.text :options
      t.timestamps
    end
    add_index :services, :user_id
    add_index :services, [:user_id, :global]
  end
end
