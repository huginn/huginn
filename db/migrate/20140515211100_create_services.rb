class CreateServices < ActiveRecord::Migration
  def change
    create_table :services do |t|
      t.integer :user_id
      t.string :provider
      t.string :name
      t.text :token
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
